import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_patient/app_lock.dart';
import 'package:cycle_patient/patient_home.dart';
import 'package:cycle_patient/patient_localizations.dart';
import 'package:cycle_patient/vault_session.dart';
import 'package:cycle_security/cycle_security.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _ClockAppLock extends AppLockService {
  @override
  bool get authInProgress => false;

  @override
  Future<bool> authenticate({
    LockSensitivity sensitivity = LockSensitivity.standard,
  }) async => true;

  @override
  Future<void> cancel() async {}
}

class _ClockRepository implements HealthEventRepository {
  _ClockRepository(this.events);

  final List<HealthEvent> events;

  @override
  Future<void> upsert(HealthEvent event) async => events.add(event);

  @override
  Future<HealthEvent?> getById(String id) async {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  Future<List<HealthEvent>> query({
    required String subjectId,
    String? eventType,
    DateTime? from,
    DateTime? to,
    bool includeSuperseded = false,
  }) async => events.where((event) => event.subjectId == subjectId).toList();

  @override
  Future<void> markDeleted({
    required String eventId,
    required DateTime deletedAt,
  }) async {}
}

class _ClockAuditLog implements AuditLogRepository {
  final List<AuditEvent> events = <AuditEvent>[];

  @override
  Future<void> append(AuditEvent event) async => events.add(event);

  @override
  Future<List<AuditEvent>> listForSubject(
    String subjectId, {
    int limit = 200,
  }) async => events
      .where((event) => event.subjectId == subjectId)
      .take(limit)
      .toList();
}

class _ClockSession extends PatientVaultSession {
  _ClockSession(this.clockRepository, this.clockAuditLog);

  final _ClockRepository clockRepository;
  final _ClockAuditLog clockAuditLog;

  @override
  HealthEventRepository get repository => clockRepository;

  @override
  AuditLogRepository get auditLog => clockAuditLog;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> unlock() async {}

  @override
  Future<void> lock() async {}

  @override
  Future<VaultState> state() async => VaultState.unlocked;
}

Widget _clockTestApp(Widget home) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: PatientLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    PatientLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

HealthEvent _periodStart(DateTime observedAt) => HealthEvent(
  id: 'clock-period-start',
  subjectId: 'local-owner',
  eventType: 'menstruation.period_start',
  temporal: TemporalMetadata(
    observedAt: observedAt,
    recordedAt: observedAt,
    knownAt: observedAt,
  ),
  provenance: const Provenance(sourceKind: SourceKind.patient),
  verificationStatus: VerificationStatus.selfReported,
  confidence: ConfidenceClass.high,
  privacyClass: 'reproductive',
  schemaVersion: 1,
);

void main() {
  testWidgets('injected clock drives cycle day and Quick Log timestamp', (
    tester,
  ) async {
    final fixedNow = DateTime.utc(2026, 9, 17, 9);
    final repository = _ClockRepository(<HealthEvent>[
      _periodStart(DateTime.utc(2026, 9, 5, 9)),
    ]);
    final session = _ClockSession(repository, _ClockAuditLog());

    await tester.pumpWidget(
      _clockTestApp(
        PatientHomePage(
          session: session,
          appLock: _ClockAppLock(),
          now: () => fixedNow,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cycle day 13'), findsOneWidget);

    await tester.tap(find.byTooltip('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('2026-09'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quick Log'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Headache'));
    await tester.pumpAndSettle();

    final created = repository.events.singleWhere(
      (event) => event.eventType == 'symptom.headache',
    );
    expect(created.id, 'event-${fixedNow.microsecondsSinceEpoch}');
    expect(created.temporal.observedAt, fixedNow);
    expect(created.temporal.recordedAt, fixedNow);
    expect(created.temporal.knownAt, fixedNow);
  });
}
