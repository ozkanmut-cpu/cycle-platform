from pathlib import Path
import plistlib
import re

app = Path.cwd()
if app.name != "patient":
    raise SystemExit("Run from apps/patient")

info = app / "ios/Runner/Info.plist"
with info.open("rb") as handle:
    plist = plistlib.load(handle)
plist["NSHealthShareUsageDescription"] = (
    "Cycle reads health data you choose to share so it can show private trends and context on this device."
)
with info.open("wb") as handle:
    plistlib.dump(plist, handle, fmt=plistlib.FMT_XML, sort_keys=False)

entitlements = app / "ios/Runner/Runner.entitlements"
with entitlements.open("wb") as handle:
    plistlib.dump(
        {"com.apple.developer.healthkit": True},
        handle,
        fmt=plistlib.FMT_XML,
        sort_keys=False,
    )

project = app / "ios/Runner.xcodeproj/project.pbxproj"
project_text = project.read_text(encoding="utf-8")
if "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;" not in project_text:
    project_text = re.sub(
        r"(\s+)(PRODUCT_BUNDLE_IDENTIFIER = )",
        r"\1CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\1\2",
        project_text,
    )
project.write_text(project_text, encoding="utf-8")

app_delegate = app / "ios/Runner/AppDelegate.swift"
app_delegate.write_text(r'''import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var healthKitBridge: HealthKitBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "CycleHealthKitBridge") {
      healthKitBridge = HealthKitBridge(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

final class HealthKitBridge {
  private let store = HKHealthStore()
  private let channel: FlutterMethodChannel
  private let supportedCategories: [String: [HKSampleType]]

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "cycle.health/native", binaryMessenger: messenger)
    supportedCategories = Self.makeSupportedCategories()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      guard call.method.hasPrefix("healthKit.") else {
        result(FlutterMethodNotImplemented)
        return
      }
      Task { @MainActor in
        do {
          switch call.method {
          case "healthKit.isAvailable":
            result(HKHealthStore.isHealthDataAvailable())
          case "healthKit.grantedCategories":
            result(try await self.authorizationReadyCategories())
          case "healthKit.requestPermissions":
            result(try await self.requestPermissions(call))
          case "healthKit.readRecords":
            result(try await self.readRecords(call))
          case "healthKit.createAnchor":
            result(try await self.createCompositeAnchor(call))
          case "healthKit.readAnchoredChanges":
            result(try await self.readAnchoredChanges(call))
          default:
            result(FlutterMethodNotImplemented)
          }
        } catch {
          result(FlutterError(
            code: "healthkit_error",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private static func makeSupportedCategories() -> [String: [HKSampleType]] {
    func quantity(_ id: HKQuantityTypeIdentifier) -> HKQuantityType {
      HKObjectType.quantityType(forIdentifier: id)!
    }
    func category(_ id: HKCategoryTypeIdentifier) -> HKCategoryType {
      HKObjectType.categoryType(forIdentifier: id)!
    }

    return [
      "reproductive": [category(.menstrualFlow)],
      "vitals": [
        quantity(.heartRate),
        quantity(.oxygenSaturation),
        quantity(.bloodGlucose),
      ],
      "sleep": [category(.sleepAnalysis)],
      "activity": [quantity(.stepCount)],
      "body": [quantity(.bodyMass), quantity(.height)],
      "nutrition": [quantity(.dietaryEnergyConsumed)],
      "wellness": [category(.mindfulSession)],
    ]
  }

  private func categories(_ call: FlutterMethodCall) -> Set<String> {
    guard
      let args = call.arguments as? [String: Any],
      let raw = args["categories"] as? [String]
    else { return [] }
    return Set(raw.filter { supportedCategories[$0] != nil })
  }

  private func sampleTypes(for categories: Set<String>) -> [HKSampleType] {
    categories.flatMap { supportedCategories[$0] ?? [] }
  }

  private func authorizationReadyCategories() async throws -> [String] {
    guard HKHealthStore.isHealthDataAvailable() else { return [] }
    var ready: [String] = []
    for (category, types) in supportedCategories {
      let status = try await requestStatus(read: Set(types))
      if status == .unnecessary {
        ready.append(category)
      }
    }
    return ready.sorted()
  }

  private func requestPermissions(_ call: FlutterMethodCall) async throws -> Bool {
    guard HKHealthStore.isHealthDataAvailable() else { return false }
    let requested = categories(call)
    let types = Set(sampleTypes(for: requested).map { $0 as HKObjectType })
    if types.isEmpty { return true }
    return try await withCheckedThrowingContinuation { continuation in
      store.requestAuthorization(toShare: [], read: types) { success, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: success)
        }
      }
    }
  }

  private func requestStatus(read types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
    try await withCheckedThrowingContinuation { continuation in
      store.getRequestStatusForAuthorization(toShare: [], read: types) { status, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: status)
        }
      }
    }
  }

  private func readRecords(_ call: FlutterMethodCall) async throws -> [[String: Any]] {
    guard HKHealthStore.isHealthDataAvailable() else { return [] }
    guard
      let args = call.arguments as? [String: Any],
      let fromMillis = (args["fromEpochMillis"] as? NSNumber)?.int64Value,
      let toMillis = (args["toEpochMillis"] as? NSNumber)?.int64Value
    else { throw BridgeError.invalidArguments }

    let start = Date(timeIntervalSince1970: TimeInterval(fromMillis) / 1000)
    let end = Date(timeIntervalSince1970: TimeInterval(toMillis) / 1000)
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
    var output: [[String: Any]] = []
    for type in sampleTypes(for: categories(call)) {
      let samples = try await sampleQuery(type: type, predicate: predicate)
      output.append(contentsOf: samples.compactMap(sampleToMap))
    }
    return output
  }

  private func sampleQuery(type: HKSampleType, predicate: NSPredicate?) async throws -> [HKSample] {
    try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: nil
      ) { _, samples, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: samples ?? [])
        }
      }
      store.execute(query)
    }
  }

  private func createCompositeAnchor(_ call: FlutterMethodCall) async throws -> String {
    guard HKHealthStore.isHealthDataAvailable() else { return encodeAnchorMap([:]) }
    var anchors: [String: String] = [:]
    for type in sampleTypes(for: categories(call)) {
      let page = try await anchoredQuery(type: type, anchor: nil)
      if let anchor = page.anchor {
        anchors[type.identifier] = try archive(anchor)
      }
    }
    return encodeAnchorMap(anchors)
  }

  private func readAnchoredChanges(_ call: FlutterMethodCall) async throws -> [String: Any] {
    guard
      let args = call.arguments as? [String: Any],
      let token = args["anchor"] as? String
    else { throw BridgeError.invalidArguments }

    let previous = try decodeAnchorMap(token)
    var next = previous
    var upserts: [[String: Any]] = []
    var deletes: [String] = []

    for type in sampleTypes(for: categories(call)) {
      let anchor = try previous[type.identifier].flatMap(unarchive)
      let page = try await anchoredQuery(type: type, anchor: anchor)
      upserts.append(contentsOf: page.samples.compactMap(sampleToMap))
      deletes.append(contentsOf: page.deleted.map { $0.uuid.uuidString })
      if let newAnchor = page.anchor {
        next[type.identifier] = try archive(newAnchor)
      }
    }

    return [
      "upserts": upserts,
      "deletedSourceRecordIds": deletes,
      "nextAnchor": encodeAnchorMap(next),
      "hasMore": false,
      "anchorInvalid": false,
    ]
  }

  private struct AnchoredPage {
    let samples: [HKSample]
    let deleted: [HKDeletedObject]
    let anchor: HKQueryAnchor?
  }

  private func anchoredQuery(type: HKSampleType, anchor: HKQueryAnchor?) async throws -> AnchoredPage {
    try await withCheckedThrowingContinuation { continuation in
      let query = HKAnchoredObjectQuery(
        type: type,
        predicate: nil,
        anchor: anchor,
        limit: HKObjectQueryNoLimit
      ) { _, samples, deleted, newAnchor, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: AnchoredPage(
            samples: samples ?? [],
            deleted: deleted ?? [],
            anchor: newAnchor
          ))
        }
      }
      store.execute(query)
    }
  }

  private func sampleToMap(_ sample: HKSample) -> [String: Any]? {
    var record: [String: Any] = [
      "sourceRecordId": sample.uuid.uuidString,
      "observedAtEpochMillis": Int64(sample.startDate.timeIntervalSince1970 * 1000),
      "sourceName": sample.sourceRevision.source.name,
      "deviceName": sample.device?.name as Any,
      "metadata": [
        "sourceBundle": sample.sourceRevision.source.bundleIdentifier,
        "endEpochMillis": Int64(sample.endDate.timeIntervalSince1970 * 1000),
      ],
    ]

    if let category = sample as? HKCategorySample {
      switch category.categoryType.identifier {
      case HKCategoryTypeIdentifier.menstrualFlow.rawValue:
        record["sourceType"] = "menstruation_flow"
        record["value"] = category.value
      case HKCategoryTypeIdentifier.sleepAnalysis.rawValue:
        record["sourceType"] = "sleep_session"
        record["value"] = sample.endDate.timeIntervalSince(sample.startDate) / 60
        record["unit"] = "min"
        record["metadata"] = (record["metadata"] as? [String: Any] ?? [:]).merging(
          ["sleepValue": category.value]
        ) { _, new in new }
      case HKCategoryTypeIdentifier.mindfulSession.rawValue:
        record["sourceType"] = "mindfulness"
        record["value"] = sample.endDate.timeIntervalSince(sample.startDate) / 60
        record["unit"] = "min"
      default:
        return nil
      }
      return record
    }

    guard let quantity = sample as? HKQuantitySample else { return nil }
    switch quantity.quantityType.identifier {
    case HKQuantityTypeIdentifier.heartRate.rawValue:
      record["sourceType"] = "heart_rate"
      record["value"] = quantity.quantity.doubleValue(
        for: HKUnit.count().unitDivided(by: .minute())
      )
      record["unit"] = "bpm"
    case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
      record["sourceType"] = "oxygen_saturation"
      record["value"] = quantity.quantity.doubleValue(for: .percent())
      record["unit"] = "%"
    case HKQuantityTypeIdentifier.bloodGlucose.rawValue:
      record["sourceType"] = "blood_glucose"
      let unit = HKUnit.moleUnit(with: .milli).unitDivided(by: .liter())
      record["value"] = quantity.quantity.doubleValue(for: unit)
      record["unit"] = "mmol/L"
    case HKQuantityTypeIdentifier.stepCount.rawValue:
      record["sourceType"] = "steps"
      record["value"] = quantity.quantity.doubleValue(for: .count())
      record["unit"] = "count"
    case HKQuantityTypeIdentifier.bodyMass.rawValue:
      record["sourceType"] = "weight"
      record["value"] = quantity.quantity.doubleValue(for: .gramUnit(with: .kilo))
      record["unit"] = "kg"
    case HKQuantityTypeIdentifier.height.rawValue:
      record["sourceType"] = "height"
      record["value"] = quantity.quantity.doubleValue(for: .meter())
      record["unit"] = "m"
    case HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue:
      record["sourceType"] = "dietary_energy"
      record["value"] = quantity.quantity.doubleValue(for: .kilocalorie())
      record["unit"] = "kcal"
    default:
      return nil
    }
    return record
  }

  private func archive(_ anchor: HKQueryAnchor) throws -> String {
    try NSKeyedArchiver.archivedData(
      withRootObject: anchor,
      requiringSecureCoding: true
    ).base64EncodedString()
  }

  private func unarchive(_ encoded: String) throws -> HKQueryAnchor? {
    guard let data = Data(base64Encoded: encoded) else {
      throw BridgeError.invalidAnchor
    }
    return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
  }

  private func encodeAnchorMap(_ anchors: [String: String]) -> String {
    let data = try! JSONSerialization.data(withJSONObject: anchors, options: [.sortedKeys])
    return data.base64EncodedString()
  }

  private func decodeAnchorMap(_ token: String) throws -> [String: String] {
    guard
      let data = Data(base64Encoded: token),
      let object = try JSONSerialization.jsonObject(with: data) as? [String: String]
    else { throw BridgeError.invalidAnchor }
    return object
  }
}

private enum BridgeError: LocalizedError {
  case invalidArguments
  case invalidAnchor

  var errorDescription: String? {
    switch self {
    case .invalidArguments: return "HealthKit bridge received invalid arguments."
    case .invalidAnchor: return "HealthKit sync anchor is invalid."
    }
  }
}
''', encoding="utf-8")
