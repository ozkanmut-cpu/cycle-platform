import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/patient_journey_driver.dart';
import 'support/patient_journey_fixtures.dart';
import 'support/patient_journey_harness.dart';
import 'support/patient_journey_suite.dart';

void main() {
  final virtualNow = DateTime.utc(2026, 9, 17, 9);

  testWidgets('privacy unlock failure contains data and supports recovery', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    final harness = PatientJourneyHarness(
      virtualNow: virtualNow,
      events: p005Events(virtualNow),
      authenticationOutcomes: const <bool>[false, true],
    );
    await harness.pumpHome(tester);

    expect(find.text('Authentication required'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
    expect(find.text('Headache').hitTestable(), findsNothing);
    expect(find.bySemanticsLabel('Headache'), findsNothing);
    expect(find.bySemanticsLabel('P-005-sensitive-headache'), findsNothing);

    final driver = PatientJourneyDriver(tester);
    await driver.tapText('Unlock');
    driver.recordRecovery();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Headache'), findsOneWidget);
    expect(harness.appLock.authenticateCalls, 2);

    await clearPatientJourneyWidgetTree(tester);
    final result = await runPrivacyUnlockRecoveryJourney(tester);
    expect(result.scenario.id, 'privacy-unlock-recovery');
    expect(result.passed, isTrue);
    expect(
      result.coverageLabels,
      containsAll(<String>[
        'family:privacyUnlockRecovery',
        'privacy:unlock-success',
        'privacy:auth-failure-recovery',
        'privacy:locked-negative-assertion',
      ]),
    );
  });

  testWidgets('lifecycle pause relocks and resume authenticates before restore', (
    tester,
  ) async {
    final harness = PatientJourneyHarness(
      virtualNow: virtualNow,
      events: p005Events(virtualNow),
      authenticationOutcomes: const <bool>[true, true],
    );
    await harness.pumpHome(tester);
    expect(find.text('Headache'), findsOneWidget);

    final driver = PatientJourneyDriver(tester);
    await driver.lifecycle(AppLifecycleState.paused);
    expect(find.text('Private data locked'), findsOneWidget);
    expect(find.text('Headache').hitTestable(), findsNothing);

    await driver.lifecycle(AppLifecycleState.resumed);
    expect(harness.appLock.authenticateCalls, 2);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Headache'), findsOneWidget);

    await clearPatientJourneyWidgetTree(tester);
    final result = await runPrivacyLifecycleRelockJourney(tester);
    expect(result.scenario.id, 'privacy-lifecycle-relock');
    expect(result.passed, isTrue);
    expect(
      result.coverageLabels,
      containsAll(<String>[
        'family:privacyLifecycleRelock',
        'privacy:lifecycle-relock',
        'privacy:locked-negative-assertion',
      ]),
    );
  });

  testWidgets('Today distinguishes known and unknown cycle day', (tester) async {
    final known = PatientJourneyHarness(
      virtualNow: virtualNow,
      events: p001Events(virtualNow),
      authenticationOutcomes: const <bool>[true],
    );
    await known.pumpHome(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Quick Log'), findsOneWidget);
    expect(find.text('Connected Health'), findsOneWidget);
    expect(find.text('Cycle day 13'), findsOneWidget);

    await clearPatientJourneyWidgetTree(tester);
    final unknown = PatientJourneyHarness(
      virtualNow: virtualNow,
      events: p002Events(virtualNow),
      authenticationOutcomes: const <bool>[true],
    );
    await unknown.pumpHome(tester);
    expect(find.text('Cycle day unknown'), findsOneWidget);
    expect(find.textContaining('Cycle day 0'), findsNothing);

    await clearPatientJourneyWidgetTree(tester);
    final results = await runTodayComprehensionJourneys(tester);
    expect(results.map((result) => result.scenario.id), <String>[
      'today-known-cycle-day',
      'today-unknown-cycle-day',
    ]);
    expect(results.every((result) => result.passed), isTrue);
    expect(
      results.first.coverageLabels,
      containsAll(<String>[
        'family:todayComprehensionSurface',
        'today:known-cycle-day',
      ]),
    );
    expect(
      results.last.coverageLabels,
      containsAll(<String>[
        'family:todayComprehensionSurface',
        'today:unknown-cycle-day',
      ]),
    );
  });
}
