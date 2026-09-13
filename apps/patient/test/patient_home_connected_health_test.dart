import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_patient/app_lock.dart';
import 'package:cycle_patient/connected_health_screen.dart';
import 'package:cycle_patient/patient_home.dart';
import 'package:cycle_patient/patient_localizations.dart';
import 'package:cycle_patient/vault_session.dart';
import 'package:cycle_security/cycle_security.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _AlwaysUnlockedAppLock extends AppLockService {
  @override
  bool get authInProgress => false;

  @override
  Future<bool> authenticate({LockSensitivity sensitivity = LockSensitivity.standard}) async => true;

  @override
  Future<void> cancel() async {}
}

class _VaultRepository implements HealthEventRepository {
  _VaultRepository(this.events);

  final List<HealthEvent> events;
  int queryCount = 0;

  @override
  Future<List<HealthEvent>> query({
    required String subjectId,
    String? eventType,
    DateTime? from,
    DateTime? to,
    bool includeSuperseded = false,
  }) async {
    queryCount += 1;
    return events.where((event) => event.subjectId == subjectId).toList();
  }

  @override
  Future<HealthEvent?> getById(String id) async {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  Future<void> upsert(HealthEvent event) async => events.add(event);

  @override
  Future<void> markDeleted({required String eventId, required DateTime deletedAt}) async {}
}

class _VaultSession extends PatientVaultSession {
  _VaultSession(this.vaultRepository);

  final _VaultRepository vaultRepository;

  @override
  HealthEventRepository get repository => vaultRepository;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> unlock() async {}

  @override
  Future<void> lock() async {}

  @override
  Future<VaultState> state() async => VaultState.unlocked;
}

HealthEvent _event({
  required String id,
  required num value,
  required SourceKind sourceKind,
  required DateTime observedAt,
}) {
  return HealthEvent(
    id: id,
    subjectId: 'local-owner',
    eventType: 'vital.oxygen_saturation',
    value: value,
    unit: '%',
    dataState: DataState.yes,
    temporal: TemporalMetadata(
      observedAt: observedAt,
      recordedAt: observedAt,
      knownAt: observedAt,
    ),
    provenance: Provenance(sourceKind: sourceKind, sourceRecordId: id),
    verificationStatus: VerificationStatus.deviceMeasured,
    confidence: ConfidenceClass.high,
    privacyClass: 'health',
    schemaVersion: 1,
  );
}

void main() {
  testWidgets('opens Connected Health from vault events and preserves aggregation conflict', (tester) async {
    final repository = _VaultRepository([
      _event(
        id: 'vault-hc-spo2',
        value: 98,
        sourceKind: SourceKind.healthConnect,
        observedAt: DateTime.utc(2026, 9, 13, 8, 5),
      ),
      _event(
        id: 'vault-hk-spo2',
        value: 91,
        sourceKind: SourceKind.healthKit,
        observedAt: DateTime.utc(2026, 9, 13, 8, 6),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: PatientLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          PatientLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: PatientHomePage(
          session: _VaultSession(repository),
          appLock: _AlwaysUnlockedAppLock(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.queryCount, 1);
    expect(find.text('Connected Health'), findsOneWidget);

    await tester.tap(find.text('Connected Health'));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectedHealthScreen), findsOneWidget);
    expect(find.text('Sources conflict'), findsOneWidget);
    expect(find.textContaining('Health Connect + HealthKit'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
