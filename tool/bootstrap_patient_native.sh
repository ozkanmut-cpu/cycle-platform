#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/patient"

cd "$APP_DIR"
flutter create \
  --platforms=android,ios \
  --org com.cyclehealth \
  --project-name cycle_patient \
  .

python3 - <<'PY'
from pathlib import Path
import plistlib

app = Path.cwd()

android_package = app / "android/app/src/main/kotlin/com/cyclehealth/cycle_patient"
android_package.mkdir(parents=True, exist_ok=True)

main_activity = android_package / "MainActivity.kt"
main_activity.write_text(
    '''package com.cyclehealth.cycle_patient

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.PermissionController
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingHealthPermissionResult: MethodChannel.Result? = null

    private val healthPermissionLauncher: ActivityResultLauncher<Set<String>> =
        registerForActivityResult(
            PermissionController.createRequestPermissionResultContract()
        ) { granted ->
            pendingHealthPermissionResult?.success(granted.toList())
            pendingHealthPermissionResult = null
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        HealthConnectBridge(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            requestPermissions = ::requestHealthPermissions,
        )
    }

    private fun requestHealthPermissions(
        permissions: Set<String>,
        result: MethodChannel.Result,
    ) {
        if (pendingHealthPermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "A Health Connect permission request is already active.",
                null,
            )
            return
        }
        pendingHealthPermissionResult = result
        healthPermissionLauncher.launch(permissions)
    }
}
''',
    encoding="utf-8",
)

health_bridge = android_package / "HealthConnectBridge.kt"
health_bridge.write_text(
    '''package com.cyclehealth.cycle_patient

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.changes.DeletionChange
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.MenstruationFlowRecord
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.request.ChangesTokenRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Duration
import java.time.Instant
import kotlin.reflect.KClass
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class HealthConnectBridge(
    private val context: Context,
    messenger: BinaryMessenger,
    private val requestPermissions: (Set<String>, MethodChannel.Result) -> Unit,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (!call.method.startsWith("healthConnect.")) {
            result.notImplemented()
            return
        }

        scope.launch {
            try {
                when (call.method) {
                    "healthConnect.isAvailable" -> result.success(isAvailable())
                    "healthConnect.grantedCategories" ->
                        result.success(grantedCategories().toList())
                    "healthConnect.requestPermissions" ->
                        requestCategoryPermissions(call, result)
                    "healthConnect.readRecords" ->
                        result.success(readRecords(call))
                    "healthConnect.createChangesToken" ->
                        result.success(createChangesToken(call))
                    "healthConnect.readChanges" ->
                        result.success(readChanges(call))
                    else -> result.notImplemented()
                }
            } catch (error: SecurityException) {
                result.error("health_connect_permission", error.message, null)
            } catch (error: Exception) {
                result.error("health_connect_error", error.message, null)
            }
        }
    }

    private fun isAvailable(): Boolean =
        HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE

    private fun client(): HealthConnectClient {
        check(isAvailable()) { "Health Connect is not available on this device." }
        return HealthConnectClient.getOrCreate(context)
    }

    private suspend fun grantedCategories(): Set<String> {
        if (!isAvailable()) return emptySet()
        val healthClient = client()
        val granted = healthClient.permissionController.getGrantedPermissions()
        return CATEGORY_RECORD_TYPES.mapNotNull { (category, types) ->
            if (types.any { HealthPermission.getReadPermission(it) in granted }) category else null
        }.toSet()
    }

    private fun requestCategoryPermissions(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        check(isAvailable()) { "Health Connect is not available on this device." }
        val requested = categories(call)
        val permissions = recordTypes(requested)
            .map { HealthPermission.getReadPermission(it) }
            .toSet()
        if (permissions.isEmpty()) {
            result.success(emptyList<String>())
            return
        }
        requestPermissions(permissions, result)
    }

    private suspend fun readRecords(call: MethodCall): List<Map<String, Any?>> {
        val healthClient = client()
        val from = Instant.ofEpochMilli(requireLong(call, "fromEpochMillis"))
        val to = Instant.ofEpochMilli(requireLong(call, "toEpochMillis"))
        val requested = categories(call)
        val filter = TimeRangeFilter.between(from, to)
        val granted = healthClient.permissionController.getGrantedPermissions()
        val records = mutableListOf<Record>()

        suspend fun <T : Record> readIfGranted(type: KClass<T>) {
            if (HealthPermission.getReadPermission(type) !in granted) return
            records += healthClient.readRecords(
                ReadRecordsRequest(
                    recordType = type,
                    timeRangeFilter = filter,
                )
            ).records
        }

        if ("reproductive" in requested) readIfGranted(MenstruationFlowRecord::class)
        if ("vitals" in requested) {
            readIfGranted(HeartRateRecord::class)
            readIfGranted(OxygenSaturationRecord::class)
            readIfGranted(BloodGlucoseRecord::class)
        }
        if ("sleep" in requested) readIfGranted(SleepSessionRecord::class)
        if ("activity" in requested) readIfGranted(StepsRecord::class)
        if ("body" in requested) {
            readIfGranted(WeightRecord::class)
            readIfGranted(HeightRecord::class)
        }
        if ("nutrition" in requested) readIfGranted(NutritionRecord::class)
        if ("wellness" in requested) readIfGranted(MindfulnessSessionRecord::class)

        return records.mapNotNull(::recordToMap)
    }

    private suspend fun createChangesToken(call: MethodCall): String {
        val healthClient = client()
        val requested = categories(call)
        val granted = healthClient.permissionController.getGrantedPermissions()
        val allowedTypes = recordTypes(requested)
            .filter { HealthPermission.getReadPermission(it) in granted }
            .toSet()
        check(allowedTypes.isNotEmpty()) {
            "No granted Health Connect record types are available for this token."
        }
        return healthClient.getChangesToken(
            ChangesTokenRequest(recordTypes = allowedTypes)
        )
    }

    private suspend fun readChanges(call: MethodCall): Map<String, Any?> {
        val healthClient = client()
        val token = call.argument<String>("token")
            ?.takeIf { it.isNotBlank() }
            ?: error("Missing Health Connect changes token.")
        val response = healthClient.getChanges(token, CHANGE_PAGE_SIZE)
        val changes = response.changes.mapNotNull { change ->
            when (change) {
                is UpsertionChange -> {
                    if (change.record.metadata.dataOrigin.packageName == context.packageName) {
                        null
                    } else {
                        recordToMap(change.record)?.let { record ->
                            mapOf("kind" to "upsert", "record" to record)
                        }
                    }
                }
                is DeletionChange ->
                    mapOf("kind" to "delete", "sourceRecordId" to change.recordId)
                else -> null
            }
        }
        return mapOf(
            "nextToken" to response.nextChangesToken,
            "hasMore" to response.hasMore,
            "tokenExpired" to response.changesTokenExpired,
            "changes" to changes,
        )
    }

    private fun categories(call: MethodCall): Set<String> =
        call.argument<List<String>>("categories")
            ?.filter { it in CATEGORY_RECORD_TYPES.keys }
            ?.toSet()
            ?: emptySet()

    private fun recordTypes(categories: Set<String>): Set<KClass<out Record>> =
        categories.flatMap { CATEGORY_RECORD_TYPES[it].orEmpty() }.toSet()

    private fun requireLong(call: MethodCall, key: String): Long =
        (call.argument<Number>(key)?.toLong())
            ?: error("Missing $key.")

    private fun recordToMap(record: Record): Map<String, Any?>? {
        val sourceName = record.metadata.dataOrigin.packageName
        val id = record.metadata.id
        val common = mutableMapOf<String, Any?>(
            "sourceRecordId" to id,
            "sourceName" to sourceName,
            "metadata" to mapOf(
                "originPackage" to sourceName,
                "lastModifiedEpochMillis" to record.metadata.lastModifiedTime.toEpochMilli(),
            ),
        )

        when (record) {
            is MenstruationFlowRecord -> common.putAll(
                mapOf(
                    "sourceType" to "menstruation_flow",
                    "observedAtEpochMillis" to record.time.toEpochMilli(),
                    "value" to record.flow,
                )
            )
            is HeartRateRecord -> common.putAll(
                mapOf(
                    "sourceType" to "heart_rate",
                    "observedAtEpochMillis" to record.startTime.toEpochMilli(),
                    "value" to record.samples.map { it.beatsPerMinute }.averageOrNull(),
                    "unit" to "bpm",
                    "metadata" to commonMetadata(record).plus(
                        "sampleCount" to record.samples.size,
                    ),
                )
            )
            is OxygenSaturationRecord -> common.putAll(
                mapOf(
                    "sourceType" to "oxygen_saturation",
                    "observedAtEpochMillis" to record.time.toEpochMilli(),
                    "value" to record.percentage.value,
                    "unit" to "%",
                )
            )
            is BloodGlucoseRecord -> common.putAll(
                mapOf(
                    "sourceType" to "blood_glucose",
                    "observedAtEpochMillis" to record.time.toEpochMilli(),
                    "value" to record.level.inMillimolesPerLiter,
                    "unit" to "mmol/L",
                )
            )
            is SleepSessionRecord -> common.putAll(
                mapOf(
                    "sourceType" to "sleep_session",
                    "observedAtEpochMillis" to record.startTime.toEpochMilli(),
                    "value" to Duration.between(record.startTime, record.endTime).toMinutes(),
                    "unit" to "min",
                    "metadata" to commonMetadata(record).plus(
                        "endEpochMillis" to record.endTime.toEpochMilli(),
                    ),
                )
            )
            is StepsRecord -> common.putAll(
                mapOf(
                    "sourceType" to "steps",
                    "observedAtEpochMillis" to record.startTime.toEpochMilli(),
                    "value" to record.count,
                    "unit" to "count",
                    "metadata" to commonMetadata(record).plus(
                        "endEpochMillis" to record.endTime.toEpochMilli(),
                    ),
                )
            )
            is WeightRecord -> common.putAll(
                mapOf(
                    "sourceType" to "weight",
                    "observedAtEpochMillis" to record.time.toEpochMilli(),
                    "value" to record.weight.inKilograms,
                    "unit" to "kg",
                )
            )
            is HeightRecord -> common.putAll(
                mapOf(
                    "sourceType" to "height",
                    "observedAtEpochMillis" to record.time.toEpochMilli(),
                    "value" to record.height.inMeters,
                    "unit" to "m",
                )
            )
            is NutritionRecord -> common.putAll(
                mapOf(
                    "sourceType" to "dietary_energy",
                    "observedAtEpochMillis" to record.startTime.toEpochMilli(),
                    "value" to record.energy?.inKilocalories,
                    "unit" to "kcal",
                    "metadata" to commonMetadata(record).plus(
                        "endEpochMillis" to record.endTime.toEpochMilli(),
                    ),
                )
            )
            is MindfulnessSessionRecord -> common.putAll(
                mapOf(
                    "sourceType" to "mindfulness",
                    "observedAtEpochMillis" to record.startTime.toEpochMilli(),
                    "value" to Duration.between(record.startTime, record.endTime).toMinutes(),
                    "unit" to "min",
                    "metadata" to commonMetadata(record).plus(
                        "endEpochMillis" to record.endTime.toEpochMilli(),
                    ),
                )
            )
            else -> return null
        }
        return common
    }

    private fun commonMetadata(record: Record): Map<String, Any?> = mapOf(
        "originPackage" to record.metadata.dataOrigin.packageName,
        "lastModifiedEpochMillis" to record.metadata.lastModifiedTime.toEpochMilli(),
    )

    private fun Iterable<Long>.averageOrNull(): Double? {
        var count = 0L
        var sum = 0.0
        for (value in this) {
            sum += value
            count++
        }
        return if (count == 0L) null else sum / count
    }

    companion object {
        private const val CHANNEL = "cycle.health/native"
        private const val CHANGE_PAGE_SIZE = 500

        private val CATEGORY_RECORD_TYPES: Map<String, Set<KClass<out Record>>> = mapOf(
            "reproductive" to setOf(MenstruationFlowRecord::class),
            "vitals" to setOf(
                HeartRateRecord::class,
                OxygenSaturationRecord::class,
                BloodGlucoseRecord::class,
            ),
            "sleep" to setOf(SleepSessionRecord::class),
            "activity" to setOf(StepsRecord::class),
            "body" to setOf(WeightRecord::class, HeightRecord::class),
            "nutrition" to setOf(NutritionRecord::class),
            "wellness" to setOf(MindfulnessSessionRecord::class),
        )
    }
}
''',
    encoding="utf-8",
)

manifest = app / "android/app/src/main/AndroidManifest.xml"
text = manifest.read_text(encoding="utf-8")
permissions = [
    "android.permission.USE_BIOMETRIC",
    "android.permission.health.READ_MENSTRUATION",
    "android.permission.health.READ_HEART_RATE",
    "android.permission.health.READ_OXYGEN_SATURATION",
    "android.permission.health.READ_BLOOD_GLUCOSE",
    "android.permission.health.READ_SLEEP",
    "android.permission.health.READ_STEPS",
    "android.permission.health.READ_WEIGHT",
    "android.permission.health.READ_HEIGHT",
    "android.permission.health.READ_NUTRITION",
    "android.permission.health.READ_MINDFULNESS",
]
insert = "\n".join(
    f'    <uses-permission android:name="{permission}" />'
    for permission in permissions
)
marker = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
if "android.permission.health.READ_HEART_RATE" not in text:
    text = text.replace(marker, marker + "\n" + insert, 1)
if "com.google.android.apps.healthdata" not in text:
    text = text.replace(
        "</manifest>",
        '    <queries>\n        <package android:name="com.google.android.apps.healthdata" />\n    </queries>\n</manifest>',
        1,
    )
manifest.write_text(text, encoding="utf-8")

settings = app / "android/settings.gradle.kts"
settings_text = settings.read_text(encoding="utf-8")
settings_text = settings_text.replace(
    'id("com.android.application") version "9.1.0" apply false',
    'id("com.android.application") version "9.1.1" apply false',
)
settings.write_text(settings_text, encoding="utf-8")

android_build = app / "android/app/build.gradle.kts"
build_text = android_build.read_text(encoding="utf-8")
build_text = build_text.replace(
    "compileSdk = flutter.compileSdkVersion",
    "compileSdk = 37",
)
if "androidx.health.connect:connect-client" not in build_text:
    build_text += '''

dependencies {
    implementation("androidx.health.connect:connect-client:1.2.0-alpha06")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
'''
android_build.write_text(build_text, encoding="utf-8")

info = app / "ios/Runner/Info.plist"
with info.open("rb") as handle:
    plist = plistlib.load(handle)
plist["NSFaceIDUsageDescription"] = (
    "Cycle uses Face ID to unlock private reproductive health data."
)
with info.open("wb") as handle:
    plistlib.dump(plist, handle, fmt=plistlib.FMT_XML, sort_keys=False)

scene_delegate = app / "ios/Runner/SceneDelegate.swift"
scene_delegate.write_text(
    "import Flutter\n"
    "import UIKit\n\n"
    "class SceneDelegate: FlutterSceneDelegate {\n"
    "  private var privacyView: UIView?\n\n"
    "  override func sceneWillResignActive(_ scene: UIScene) {\n"
    "    super.sceneWillResignActive(scene)\n"
    "    guard let window = window, privacyView == nil else { return }\n"
    "    let cover = UIView(frame: window.bounds)\n"
    "    cover.backgroundColor = .systemBackground\n"
    "    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]\n"
    "    window.addSubview(cover)\n"
    "    privacyView = cover\n"
    "  }\n\n"
    "  override func sceneDidBecomeActive(_ scene: UIScene) {\n"
    "    super.sceneDidBecomeActive(scene)\n"
    "    privacyView?.removeFromSuperview()\n"
    "    privacyView = nil\n"
    "  }\n"
    "}\n",
    encoding="utf-8",
)
PY

echo "Patient Android/iOS shell configured with local authentication, Health Connect, API 37, screenshot protection, app-switcher privacy, and device-local Keychain storage."
