import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_patient/connected_health_screen.dart';
import 'package:cycle_patient/month_calendar.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'patient_journey_driver.dart';
import 'patient_journey_fixtures.dart';
import 'patient_journey_harness.dart';
import 'patient_journey_models.dart';

const int _patientJourneySeed = 20260917;

Future<PatientJourneyResult> runPrivacyUnlockRecoveryJourney(
  WidgetTester tester,
) async {
  final virtualNow = DateTime.utc(2026, 9, 17, 9);
  final harness = PatientJourneyHarness(
    virtualNow: virtualNow,
    events: p005Events(virtualNow),
    authenticationOutcomes: const <bool>[false, true],
  );
  await harness.pumpHome(tester);
  final semantics = tester.ensureSemantics();
  final driver = PatientJourneyDriver(tester);
  final privacyCoverVisible = find
      .text('Authentication is required to open private health data.')
      .evaluate()
      .isNotEmpty;
  final recoveryAffordanceVisible = find.text('Unlock').evaluate().isNotEmpty;
  final privacyCoverBypassed = find
      .text('Headache')
      .hitTestable()
      .evaluate()
      .isNotEmpty;
  final sensitiveMarkerVisible = find
      .bySemanticsLabel('Headache')
      .evaluate()
      .isNotEmpty;

  await driver.tapText('Unlock');
  driver.recordRecovery();
  final surfaceReached = find.text('Today').evaluate().isNotEmpty
      ? 'today'
      : null;
  semantics.dispose();

  final scenario = PatientJourneyScenario(
    id: 'privacy-unlock-recovery',
    schemaVersion: 1,
    seed: _patientJourneySeed,
    virtualNow: virtualNow,
    fixtureId: 'P-005',
    locale: 'en',
    family: PatientJourneyFamily.privacyUnlockRecovery,
    actions: const <String>['launch-home', 'retry-unlock'],
    assertions: const <String>[
      'privacy-cover-active',
      'privacy-no-sensitive-content',
      'recovery-affordance-visible',
      'today-visible-after-recovery',
    ],
    expectedRecoveryAffordances: const <String>['unlock'],
    riskTags: const <String>['privacy', 'authentication'],
  );
  final result = PatientJourneyDetector().evaluate(
    scenario: scenario,
    observation: PatientJourneyObservation(
      surfaceReached: surfaceReached,
      satisfiedAssertions: <String>[
        if (privacyCoverVisible) 'privacy-cover-active',
        if (!sensitiveMarkerVisible) 'privacy-no-sensitive-content',
        if (recoveryAffordanceVisible) 'recovery-affordance-visible',
        if (surfaceReached == 'today') 'today-visible-after-recovery',
      ],
      privacyCoverVisible: privacyCoverVisible,
      privacyCoverBypassed: privacyCoverBypassed,
      sensitiveMarkerVisible: sensitiveMarkerVisible,
      coreJourneyBlocked: surfaceReached != 'today',
      recoveryAffordanceVisible: recoveryAffordanceVisible,
      actionCount: driver.actionCount,
      navigationCount: driver.navigationCount,
      recoveryCount: driver.recoveryCount,
    ),
    coverageLabels: const <String>{
      'family:privacyUnlockRecovery',
      'privacy:unlock-success',
      'privacy:auth-failure-recovery',
      'privacy:locked-negative-assertion',
      'fixture:P-005',
      'control:positive',
      'control:negative',
    },
  );
  await clearPatientJourneyWidgetTree(tester);
  return result;
}

Future<PatientJourneyResult> runPrivacyLifecycleRelockJourney(
  WidgetTester tester,
) async {
  final virtualNow = DateTime.utc(2026, 9, 17, 9);
  final harness = PatientJourneyHarness(
    virtualNow: virtualNow,
    events: p005Events(virtualNow),
    authenticationOutcomes: const <bool>[true, true],
  );
  await harness.pumpHome(tester);
  final semantics = tester.ensureSemantics();
  final driver = PatientJourneyDriver(tester);

  await driver.lifecycle(AppLifecycleState.inactive);
  final privacyCoverVisible = find
      .text('Private health data is locked.')
      .evaluate()
      .isNotEmpty;
  final privacyCoverBypassed = find
      .text('Headache')
      .hitTestable()
      .evaluate()
      .isNotEmpty;
  final sensitiveMarkerVisible = find
      .bySemanticsLabel('Headache')
      .evaluate()
      .isNotEmpty;
  await driver.lifecycle(AppLifecycleState.paused);
  await driver.lifecycle(AppLifecycleState.resumed);
  final surfaceReached = find.text('Today').evaluate().isNotEmpty
      ? 'today'
      : null;
  semantics.dispose();

  final scenario = PatientJourneyScenario(
    id: 'privacy-lifecycle-relock',
    schemaVersion: 1,
    seed: _patientJourneySeed,
    virtualNow: virtualNow,
    fixtureId: 'P-005',
    locale: 'en',
    family: PatientJourneyFamily.privacyLifecycleRelock,
    actions: const <String>[
      'launch-home',
      'inactivate-app',
      'pause-app',
      'resume-app',
    ],
    assertions: const <String>[
      'privacy-cover-active',
      'privacy-no-sensitive-content',
      'today-visible-after-resume',
    ],
    riskTags: const <String>['privacy', 'lifecycle'],
  );
  final result = PatientJourneyDetector().evaluate(
    scenario: scenario,
    observation: PatientJourneyObservation(
      surfaceReached: surfaceReached,
      satisfiedAssertions: <String>[
        if (privacyCoverVisible) 'privacy-cover-active',
        if (!sensitiveMarkerVisible) 'privacy-no-sensitive-content',
        if (surfaceReached == 'today') 'today-visible-after-resume',
      ],
      privacyCoverVisible: privacyCoverVisible,
      privacyCoverBypassed: privacyCoverBypassed,
      sensitiveMarkerVisible: sensitiveMarkerVisible,
      coreJourneyBlocked:
          surfaceReached != 'today' || harness.appLock.authenticateCalls != 2,
      actionCount: driver.actionCount,
      navigationCount: driver.navigationCount,
      recoveryCount: driver.recoveryCount,
    ),
    coverageLabels: const <String>{
      'family:privacyLifecycleRelock',
      'privacy:lifecycle-relock',
      'privacy:locked-negative-assertion',
      'fixture:P-005',
      'control:positive',
      'control:negative',
    },
  );
  await clearPatientJourneyWidgetTree(tester);
  return result;
}

Future<List<PatientJourneyResult>> runTodayComprehensionJourneys(
  WidgetTester tester,
) async {
  final virtualNow = DateTime.utc(2026, 9, 17, 9);
  final detector = PatientJourneyDetector();
  final results = <PatientJourneyResult>[];

  final known = PatientJourneyHarness(
    virtualNow: virtualNow,
    events: p001Events(virtualNow),
    authenticationOutcomes: const <bool>[true],
  );
  await known.pumpHome(tester);
  final knownToday = find.text('Today').evaluate().isNotEmpty;
  final knownQuickLog = find.text('Quick Log').evaluate().isNotEmpty;
  final knownConnectedHealth = find
      .text('Connected Health')
      .evaluate()
      .isNotEmpty;
  final knownCycleDay = find.text('Cycle day 13').evaluate().isNotEmpty;
  results.add(
    detector.evaluate(
      scenario: PatientJourneyScenario(
        id: 'today-known-cycle-day',
        schemaVersion: 1,
        seed: _patientJourneySeed,
        virtualNow: virtualNow,
        fixtureId: 'P-001',
        locale: 'en',
        family: PatientJourneyFamily.todayComprehensionSurface,
        actions: const <String>['launch-home'],
        assertions: const <String>[
          'today-visible',
          'quick-log-visible',
          'connected-health-visible',
          'known-cycle-day-visible',
        ],
      ),
      observation: PatientJourneyObservation(
        surfaceReached: knownToday ? 'today' : null,
        satisfiedAssertions: <String>[
          if (knownToday) 'today-visible',
          if (knownQuickLog) 'quick-log-visible',
          if (knownConnectedHealth) 'connected-health-visible',
          if (knownCycleDay) 'known-cycle-day-visible',
        ],
        coreJourneyBlocked:
            !knownToday ||
            !knownQuickLog ||
            !knownConnectedHealth ||
            !knownCycleDay,
      ),
      coverageLabels: const <String>{
        'family:todayComprehensionSurface',
        'today:known-cycle-day',
        'fixture:P-001',
        'control:positive',
      },
    ),
  );

  await clearPatientJourneyWidgetTree(tester);
  final unknown = PatientJourneyHarness(
    virtualNow: virtualNow,
    events: p002Events(virtualNow),
    authenticationOutcomes: const <bool>[true],
  );
  await unknown.pumpHome(tester);
  final unknownCycleDay = find.text('Cycle day unknown').evaluate().isNotEmpty;
  final cycleDayZero = find.textContaining('Cycle day 0').evaluate().isNotEmpty;
  results.add(
    detector.evaluate(
      scenario: PatientJourneyScenario(
        id: 'today-unknown-cycle-day',
        schemaVersion: 1,
        seed: _patientJourneySeed,
        virtualNow: virtualNow,
        fixtureId: 'P-002',
        locale: 'en',
        family: PatientJourneyFamily.todayComprehensionSurface,
        actions: const <String>['launch-home'],
        assertions: const <String>[
          'unknown-cycle-day-visible',
          'unknown-cycle-day-not-zero',
        ],
      ),
      observation: PatientJourneyObservation(
        surfaceReached: unknownCycleDay ? 'today' : null,
        satisfiedAssertions: <String>[
          if (unknownCycleDay) 'unknown-cycle-day-visible',
          if (!cycleDayZero) 'unknown-cycle-day-not-zero',
        ],
        missingDisplayedAsZero: cycleDayZero,
        coreJourneyBlocked: !unknownCycleDay,
      ),
      coverageLabels: const <String>{
        'family:todayComprehensionSurface',
        'today:unknown-cycle-day',
        'fixture:P-002',
        'control:negative',
      },
    ),
  );

  await clearPatientJourneyWidgetTree(tester);
  return results;
}

Future<PatientJourneyResult> runQuickLogPersistenceJourney(
  WidgetTester tester,
) async {
  final virtualNow = DateTime.utc(2026, 9, 17, 9);
  final harness = PatientJourneyHarness(
    virtualNow: virtualNow,
    events: p001Events(virtualNow),
    authenticationOutcomes: const <bool>[true],
  );
  await harness.pumpHome(tester);
  final driver = PatientJourneyDriver(tester);
  final beforeCount = harness.repository.events.length;

  await driver.tapText('Quick Log');
  driver.recordNavigation();
  await driver.tapText('Headache');

  final createdEvents = harness.repository.events
      .where((event) => event.eventType == 'symptom.headache')
      .toList();
  final created = createdEvents.length == 1 ? createdEvents.single : null;
  final repositoryEventDelta = harness.repository.events.length - beforeCount;
  final persistenceMatched =
      repositoryEventDelta == 1 &&
      created?.id == 'event-${virtualNow.microsecondsSinceEpoch}' &&
      created?.temporal.observedAt == virtualNow &&
      created?.temporal.recordedAt == virtualNow &&
      created?.temporal.knownAt == virtualNow;
  final auditMatched =
      harness.audit.events.length == 1 &&
      harness.audit.events.single.action == AuditAction.created &&
      harness.audit.events.single.subjectType == 'health_event' &&
      harness.audit.events.single.subjectId == created?.id;
  final timelineRetrieved = find.text('Headache').evaluate().isNotEmpty;

  final result = PatientJourneyDetector().evaluate(
    scenario: PatientJourneyScenario(
      id: 'quick-log-persistence',
      schemaVersion: 1,
      seed: _patientJourneySeed,
      virtualNow: virtualNow,
      fixtureId: 'P-001',
      locale: 'en',
      family: PatientJourneyFamily.quickLogPersistence,
      actions: const <String>['launch-home', 'open-quick-log', 'log-headache'],
      assertions: const <String>[
        'quick-log-persisted',
        'quick-log-audit-matched',
        'timeline-event-visible',
      ],
      riskTags: const <String>['persistence', 'audit'],
    ),
    observation: PatientJourneyObservation(
      surfaceReached: timelineRetrieved ? 'timeline' : null,
      satisfiedAssertions: <String>[
        if (persistenceMatched) 'quick-log-persisted',
        if (auditMatched) 'quick-log-audit-matched',
        if (timelineRetrieved) 'timeline-event-visible',
      ],
      repositoryEventDelta: repositoryEventDelta,
      persistedEventType: created?.eventType,
      auditActions: harness.audit.events
          .map((event) => event.action.name)
          .toList(),
      timelineExpected: true,
      timelineRetrieved: timelineRetrieved,
      coreJourneyBlocked: !timelineRetrieved,
      persistenceMatched: persistenceMatched,
      auditMatched: auditMatched,
      actionCount: driver.actionCount,
      navigationCount: driver.navigationCount,
      recoveryCount: driver.recoveryCount,
    ),
    coverageLabels: const <String>{
      'family:quickLogPersistence',
      'quick-log:persistence',
      'quick-log:audit',
      'quick-log:timeline-visible',
      'fixture:P-001',
      'control:positive',
    },
  );
  await clearPatientJourneyWidgetTree(tester);
  return result;
}

Future<PatientJourneyResult> runTimelineCalendarRetrievalJourney(
  WidgetTester tester,
) async {
  final virtualNow = DateTime.utc(2026, 9, 17, 9);
  final harness = PatientJourneyHarness(
    virtualNow: virtualNow,
    events: p001Events(virtualNow),
    authenticationOutcomes: const <bool>[true],
  );
  await harness.pumpHome(tester);
  final driver = PatientJourneyDriver(tester);
  final semantics = tester.ensureSemantics();

  final timelineRetrieved = find.text('Period started').evaluate().isNotEmpty;
  await driver.tapTooltip('Calendar');
  driver.recordNavigation();
  final monthVisible = find.text('2026-09').evaluate().isNotEmpty;
  final eventDay = find.bySemanticsLabel(RegExp(r'^2026-9-5, 2 events'));
  final eventDayVisible = eventDay.evaluate().isNotEmpty;
  if (eventDayVisible) {
    await tester.tap(eventDay);
    driver.actionCount += 1;
    await tester.pumpAndSettle();
  }
  final calendar = find.byType(MonthCalendar);
  final calendarRetrieved =
      monthVisible &&
      eventDayVisible &&
      find
          .descendant(of: calendar, matching: find.text('05.09.2026'))
          .evaluate()
          .isNotEmpty &&
      find
          .descendant(of: calendar, matching: find.text('2 logged event(s)'))
          .evaluate()
          .isNotEmpty;
  semantics.dispose();

  final result = PatientJourneyDetector().evaluate(
    scenario: PatientJourneyScenario(
      id: 'timeline-calendar-retrieval',
      schemaVersion: 1,
      seed: _patientJourneySeed,
      virtualNow: virtualNow,
      fixtureId: 'P-001',
      locale: 'en',
      family: PatientJourneyFamily.timelineCalendarRetrieval,
      actions: const <String>[
        'launch-home',
        'inspect-timeline',
        'open-calendar',
        'select-prior-event-day',
      ],
      assertions: const <String>[
        'timeline-event-visible',
        'calendar-event-visible',
      ],
      riskTags: const <String>['retrieval'],
    ),
    observation: PatientJourneyObservation(
      surfaceReached: calendarRetrieved ? 'calendar' : null,
      satisfiedAssertions: <String>[
        if (timelineRetrieved) 'timeline-event-visible',
        if (calendarRetrieved) 'calendar-event-visible',
      ],
      timelineExpected: true,
      timelineRetrieved: timelineRetrieved,
      calendarExpected: true,
      calendarRetrieved: calendarRetrieved,
      coreJourneyBlocked: !timelineRetrieved || !calendarRetrieved,
      actionCount: driver.actionCount,
      navigationCount: driver.navigationCount,
      recoveryCount: driver.recoveryCount,
    ),
    coverageLabels: const <String>{
      'family:timelineCalendarRetrieval',
      'history:timeline',
      'history:calendar',
      'fixture:P-001',
      'control:positive',
    },
  );
  await clearPatientJourneyWidgetTree(tester);
  return result;
}

Future<List<PatientJourneyResult>> runConnectedHealthJourneys(
  WidgetTester tester,
) async {
  final virtualNow = DateTime.utc(2026, 9, 17, 9);
  final detector = PatientJourneyDetector();
  final results = <PatientJourneyResult>[];

  final observedHarness = PatientJourneyHarness(
    virtualNow: virtualNow,
    events: <HealthEvent>[
      patientJourneyEvent(
        id: 'P-002-observed-spo2-health-connect',
        eventType: 'vital.oxygen_saturation',
        observedAt: DateTime.utc(2026, 9, 17, 8),
        value: 98,
        unit: '%',
        sourceKind: SourceKind.healthConnect,
        privacyClass: 'health',
      ),
    ],
    authenticationOutcomes: const <bool>[true],
  );
  await observedHarness.pumpHome(tester);
  final observedDriver = PatientJourneyDriver(tester);
  await observedDriver.tapText('Connected Health');
  observedDriver.recordNavigation();
  await observedDriver.scrollUntilVisible(find.text('SpO2'));
  final observedMatched =
      find.text('SpO2').evaluate().isNotEmpty &&
      find.text('98.0 %').evaluate().isNotEmpty &&
      find.textContaining('Observed · Health Connect').evaluate().isNotEmpty;
  results.add(
    detector.evaluate(
      scenario: PatientJourneyScenario(
        id: 'connected-health-observed-provenance-home',
        schemaVersion: 1,
        seed: _patientJourneySeed,
        virtualNow: virtualNow,
        fixtureId: 'P-002',
        locale: 'en',
        family: PatientJourneyFamily.connectedHealthStates,
        actions: const <String>['launch-home', 'open-connected-health'],
        assertions: const <String>[
          'connected-health-observed-visible',
          'connected-health-provenance-visible',
        ],
        riskTags: const <String>['connected-health', 'provenance'],
      ),
      observation: PatientJourneyObservation(
        surfaceReached: observedMatched ? 'connected-health' : null,
        satisfiedAssertions: <String>[
          if (observedMatched) 'connected-health-observed-visible',
          if (observedMatched) 'connected-health-provenance-visible',
        ],
        connectedHealthStateMatched: observedMatched,
        connectedHealthStates: const <String>['observed', 'provenance'],
        connectedHealthCoverageSource: 'home-route',
        coreJourneyBlocked: !observedMatched,
        actionCount: observedDriver.actionCount,
        navigationCount: observedDriver.navigationCount,
        recoveryCount: observedDriver.recoveryCount,
      ),
      coverageLabels: const <String>{
        'family:connectedHealthStates',
        'connected-health:observed-home',
        'connected-health:provenance-home',
        'fixture:P-002',
        'control:positive',
      },
    ),
  );

  await clearPatientJourneyWidgetTree(tester);
  final missingHarness = PatientJourneyHarness(
    virtualNow: virtualNow,
    events: const <HealthEvent>[],
    authenticationOutcomes: const <bool>[true],
  );
  await missingHarness.pumpHome(tester);
  final missingDriver = PatientJourneyDriver(tester);
  await missingDriver.tapText('Connected Health');
  missingDriver.recordNavigation();
  final missingAsZero = find.text('0').evaluate().isNotEmpty;
  final missingMatched =
      find.text('No connected health data yet.').evaluate().isNotEmpty &&
      !missingAsZero;
  results.add(
    detector.evaluate(
      scenario: PatientJourneyScenario(
        id: 'connected-health-missing-home',
        schemaVersion: 1,
        seed: _patientJourneySeed,
        virtualNow: virtualNow,
        fixtureId: 'P-002',
        locale: 'en',
        family: PatientJourneyFamily.connectedHealthStates,
        actions: const <String>['launch-home', 'open-connected-health'],
        assertions: const <String>[
          'connected-health-missing-visible',
          'connected-health-missing-not-zero',
        ],
        riskTags: const <String>['connected-health', 'missing-data'],
      ),
      observation: PatientJourneyObservation(
        surfaceReached: missingMatched ? 'connected-health' : null,
        satisfiedAssertions: <String>[
          if (missingMatched) 'connected-health-missing-visible',
          if (!missingAsZero) 'connected-health-missing-not-zero',
        ],
        missingDisplayedAsZero: missingAsZero,
        connectedHealthStateMatched: missingMatched,
        connectedHealthStates: const <String>['missing'],
        connectedHealthCoverageSource: 'home-route',
        coreJourneyBlocked: !missingMatched,
        actionCount: missingDriver.actionCount,
        navigationCount: missingDriver.navigationCount,
        recoveryCount: missingDriver.recoveryCount,
      ),
      coverageLabels: const <String>{
        'family:connectedHealthStates',
        'connected-health:missing-home',
        'fixture:P-002',
        'control:negative',
      },
    ),
  );

  await clearPatientJourneyWidgetTree(tester);
  final conflictingHarness = PatientJourneyHarness(
    virtualNow: virtualNow,
    events: p002Events(virtualNow),
    authenticationOutcomes: const <bool>[true],
  );
  await conflictingHarness.pumpHome(tester);
  final conflictingDriver = PatientJourneyDriver(tester);
  await conflictingDriver.tapText('Connected Health');
  conflictingDriver.recordNavigation();
  await conflictingDriver.scrollUntilVisible(find.text('SpO2'));
  final conflictDisplayedAsCertain = find.text('94.5 %').evaluate().isNotEmpty;
  final conflictingMatched =
      find.text('Sources conflict').evaluate().isNotEmpty &&
      find.textContaining('Health Connect + HealthKit').evaluate().isNotEmpty &&
      !conflictDisplayedAsCertain &&
      find.text('0').evaluate().isEmpty;
  results.add(
    detector.evaluate(
      scenario: PatientJourneyScenario(
        id: 'connected-health-conflicting-home',
        schemaVersion: 1,
        seed: _patientJourneySeed,
        virtualNow: virtualNow,
        fixtureId: 'P-002',
        locale: 'en',
        family: PatientJourneyFamily.connectedHealthStates,
        actions: const <String>['launch-home', 'open-connected-health'],
        assertions: const <String>[
          'connected-health-conflict-visible',
          'connected-health-conflict-not-certain',
        ],
        riskTags: const <String>['connected-health', 'conflict'],
      ),
      observation: PatientJourneyObservation(
        surfaceReached: conflictingMatched ? 'connected-health' : null,
        satisfiedAssertions: <String>[
          if (conflictingMatched) 'connected-health-conflict-visible',
          if (!conflictDisplayedAsCertain)
            'connected-health-conflict-not-certain',
        ],
        conflictDisplayedAsCertain: conflictDisplayedAsCertain,
        connectedHealthStateMatched: conflictingMatched,
        connectedHealthStates: const <String>['conflicting'],
        connectedHealthCoverageSource: 'home-route',
        coreJourneyBlocked: !conflictingMatched,
        actionCount: conflictingDriver.actionCount,
        navigationCount: conflictingDriver.navigationCount,
        recoveryCount: conflictingDriver.recoveryCount,
      ),
      coverageLabels: const <String>{
        'family:connectedHealthStates',
        'connected-health:conflicting-home',
        'fixture:P-002',
        'control:negative',
      },
    ),
  );

  await clearPatientJourneyWidgetTree(tester);
  await tester.pumpWidget(
    buildPatientJourneyApp(
      home: const ConnectedHealthScreen(
        viewModel: ConnectedHealthViewModel(
          metrics: <ConnectedHealthMetricSummary>[
            ConnectedHealthMetricSummary(
              label: 'SpO2',
              state: ConnectedHealthMetricState.stale,
              sourceLabel: 'Health Connect',
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final staleAsZero = find.text('0').evaluate().isNotEmpty;
  final staleMatched =
      find.text('Data stale').evaluate().isNotEmpty &&
      find.textContaining('Health Connect').evaluate().isNotEmpty &&
      !staleAsZero;
  results.add(
    detector.evaluate(
      scenario: PatientJourneyScenario(
        id: 'connected-health-stale-direct-widget',
        schemaVersion: 1,
        seed: _patientJourneySeed,
        virtualNow: virtualNow,
        fixtureId: 'P-002',
        locale: 'en',
        family: PatientJourneyFamily.connectedHealthStates,
        actions: const <String>['pump-connected-health-screen'],
        assertions: const <String>[
          'connected-health-stale-visible',
          'connected-health-stale-not-zero',
        ],
        riskTags: const <String>['connected-health', 'stale-data'],
      ),
      observation: PatientJourneyObservation(
        surfaceReached: staleMatched ? 'connected-health' : null,
        satisfiedAssertions: <String>[
          if (staleMatched) 'connected-health-stale-visible',
          if (!staleAsZero) 'connected-health-stale-not-zero',
        ],
        missingDisplayedAsZero: staleAsZero,
        connectedHealthStateMatched: staleMatched,
        connectedHealthStates: const <String>['stale'],
        connectedHealthCoverageSource: 'direct-production-widget',
        coreJourneyBlocked: !staleMatched,
      ),
      coverageLabels: const <String>{
        'family:connectedHealthStates',
        'connected-health:stale-direct-widget',
        'fixture:P-002',
        'control:negative',
      },
    ),
  );

  await clearPatientJourneyWidgetTree(tester);
  return results;
}
