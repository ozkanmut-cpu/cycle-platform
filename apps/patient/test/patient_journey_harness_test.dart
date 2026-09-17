import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/patient_journey_fixtures.dart';
import 'support/patient_journey_harness.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 9, 17, 9);

  test('queued app lock returns authentication outcomes in order', () async {
    final lock = QueuedJourneyAppLock(<bool>[false, true]);
    expect(await lock.authenticate(), isFalse);
    expect(await lock.authenticate(), isTrue);
    expect(lock.authenticateCalls, 2);
    await expectLater(lock.authenticate(), throwsStateError);
  });

  test('mutable clock advances from the fixed UTC instant', () {
    final clock = MutablePatientJourneyClock(fixedNow);
    expect(clock.now(), fixedNow);
    clock.advance(const Duration(minutes: 15));
    expect(clock.now(), DateTime.utc(2026, 9, 17, 9, 15));
  });

  test('fixtures reject non-UTC virtual time', () {
    expect(() => p001Events(DateTime(2026, 9, 17, 9)), throwsArgumentError);
    expect(() => p002Events(DateTime(2026, 9, 17, 9)), throwsArgumentError);
    expect(() => p005Events(DateTime(2026, 9, 17, 9)), throwsArgumentError);
  });

  test('canonical fixtures preserve synthetic ids and provenance', () {
    final p001 = p001Events(fixedNow);
    final p002 = p002Events(fixedNow);
    final p005 = p005Events(fixedNow);

    expect(p001.map((event) => event.id), <String>[
      'P-001-period-start-20260905',
      'P-001-cramps-20260905',
    ]);
    expect(p002.map((event) => event.id), <String>[
      'P-002-spo2-health-connect',
      'P-002-spo2-healthkit',
    ]);
    expect(p002.map((event) => event.value), <num>[98, 91]);
    expect(p002.map((event) => event.provenance.sourceKind), <SourceKind>[
      SourceKind.healthConnect,
      SourceKind.healthKit,
    ]);
    expect(p005.single.id, 'P-005-sensitive-headache');
    expect(
      <HealthEvent>[
        ...p001,
        ...p002,
        ...p005,
      ].every((event) => event.subjectId == 'local-owner'),
      isTrue,
    );
  });

  test('journey repository preserves stable upsert/query order', () async {
    final repository = JourneyHealthEventRepository(p001Events(fixedNow));
    final newEvent = patientJourneyEvent(
      id: 'P-001-headache-20260917',
      eventType: 'symptom.headache',
      observedAt: fixedNow,
    );
    final expectedIds = <String>[
      ...p001Events(fixedNow).map((event) => event.id),
      newEvent.id,
    ];

    await repository.upsert(newEvent);
    final events = await repository.query(subjectId: 'local-owner');
    expect(events.map((event) => event.id), containsAllInOrder(expectedIds));
  });

  test(
    'journey repository replaces, filters, and deletes deterministically',
    () async {
      final original = patientJourneyEvent(
        id: 'stable-id',
        eventType: 'symptom.headache',
        observedAt: fixedNow,
        severity: 1,
      );
      final replacement = patientJourneyEvent(
        id: 'stable-id',
        eventType: 'symptom.headache',
        observedAt: fixedNow,
        severity: 3,
      );
      final repository = JourneyHealthEventRepository(<HealthEvent>[original]);

      await repository.upsert(replacement);
      expect(repository.events, hasLength(1));
      expect((await repository.getById('stable-id'))!.severity, 3);
      expect(
        await repository.query(
          subjectId: 'local-owner',
          eventType: 'symptom.cramps',
        ),
        isEmpty,
      );
      await repository.markDeleted(eventId: 'stable-id', deletedAt: fixedNow);
      expect(await repository.getById('stable-id'), isNull);
      expect(await repository.query(subjectId: 'local-owner'), isEmpty);
    },
  );

  test('journey session records deterministic state transitions', () async {
    final repository = JourneyHealthEventRepository(const <HealthEvent>[]);
    final audit = JourneyAuditLogRepository();
    final session = JourneyPatientVaultSession(repository, audit);

    expect(await session.state(), VaultState.uninitialized);
    await session.initialize();
    expect(await session.state(), VaultState.unlocked);
    await session.lock();
    expect(await session.state(), VaultState.locked);
    await session.unlock();
    expect(await session.state(), VaultState.unlocked);
    expect(session.initializeCalls, 1);
    expect(session.lockCalls, 1);
    expect(session.unlockCalls, 1);
  });

  test(
    'journey audit log preserves append order and subject filtering',
    () async {
      final audit = JourneyAuditLogRepository();
      final first = AuditEvent(
        id: 'audit-1',
        action: AuditAction.created,
        occurredAt: fixedNow,
        actorId: 'local-owner',
        subjectType: 'health_event',
        subjectId: 'local-owner',
      );
      final second = AuditEvent(
        id: 'audit-2',
        action: AuditAction.updated,
        occurredAt: fixedNow.add(const Duration(minutes: 1)),
        actorId: 'local-owner',
        subjectType: 'health_event',
        subjectId: 'local-owner',
      );
      await audit.append(first);
      await audit.append(second);

      expect(
        (await audit.listForSubject('local-owner')).map((event) => event.id),
        <String>['audit-1', 'audit-2'],
      );
      expect(await audit.listForSubject('other-owner'), isEmpty);
    },
  );

  testWidgets('localized bootstrap and cleanup isolate fresh harnesses', (
    tester,
  ) async {
    final first = PatientJourneyHarness(
      virtualNow: fixedNow,
      events: p001Events(fixedNow),
      authenticationOutcomes: const <bool>[true],
    );
    await first.pumpHome(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Cycle day 13'), findsOneWidget);

    await clearPatientJourneyWidgetTree(tester);
    expect(find.text('Today'), findsNothing);

    final second = PatientJourneyHarness(
      virtualNow: fixedNow,
      events: p002Events(fixedNow),
      authenticationOutcomes: const <bool>[true],
    );
    await second.pumpHome(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Cycle day unknown'), findsOneWidget);
    expect(first.repository.events, hasLength(2));
    expect(second.repository.events, hasLength(2));
  });
}
