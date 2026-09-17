import 'package:cycle_storage/cycle_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/patient_journey_driver.dart';
import 'support/patient_journey_fixtures.dart';
import 'support/patient_journey_harness.dart';
import 'support/patient_journey_suite.dart';

void main() {
  testWidgets('Quick Log persists, audits, and appears in the timeline', (
    tester,
  ) async {
    final fixedNow = DateTime.utc(2026, 9, 17, 9);
    final harness = PatientJourneyHarness(
      virtualNow: fixedNow,
      events: p001Events(fixedNow),
      authenticationOutcomes: const <bool>[true],
    );
    await harness.pumpHome(tester);
    final driver = PatientJourneyDriver(tester);
    final beforeCount = harness.repository.events.length;

    await driver.tapText('Quick Log');
    await driver.tapText('Headache');

    final created = harness.repository.events.singleWhere(
      (event) => event.eventType == 'symptom.headache',
    );
    expect(harness.repository.events.length - beforeCount, 1);
    expect(created.id, 'event-${fixedNow.microsecondsSinceEpoch}');
    expect(
      harness.audit.events.map((event) => event.action),
      contains(AuditAction.created),
    );
    expect(find.text('Headache'), findsOneWidget);

    await clearPatientJourneyWidgetTree(tester);
    final result = await runQuickLogPersistenceJourney(tester);

    expect(result.scenario.id, 'quick-log-persistence');
    expect(result.passed, isTrue);
    expect(
      result.coverageLabels,
      containsAll(<String>{
        'quick-log:persistence',
        'quick-log:audit',
        'quick-log:timeline-visible',
      }),
    );
  });

  testWidgets('timeline and calendar retrieve prior fixture events', (
    tester,
  ) async {
    final fixedNow = DateTime.utc(2026, 9, 17, 9);
    final harness = PatientJourneyHarness(
      virtualNow: fixedNow,
      events: p001Events(fixedNow),
      authenticationOutcomes: const <bool>[true],
    );
    await harness.pumpHome(tester);
    final driver = PatientJourneyDriver(tester);
    final semantics = tester.ensureSemantics();

    try {
      expect(find.text('Period started'), findsOneWidget);
      await driver.tapTooltip('Calendar');
      expect(find.text('2026-09'), findsOneWidget);
      await tester.tap(
        find.bySemanticsLabel(RegExp(r'^2026-9-5, 2 events')),
      );
      await tester.pumpAndSettle();
      expect(find.text('05.09.2026'), findsOneWidget);
      expect(find.text('2 logged event(s)'), findsOneWidget);
    } finally {
      semantics.dispose();
    }

    await clearPatientJourneyWidgetTree(tester);
    final result = await runTimelineCalendarRetrievalJourney(tester);

    expect(result.scenario.id, 'timeline-calendar-retrieval');
    expect(result.passed, isTrue);
    expect(
      result.coverageLabels,
      containsAll(<String>{'history:timeline', 'history:calendar'}),
    );
  });
}
