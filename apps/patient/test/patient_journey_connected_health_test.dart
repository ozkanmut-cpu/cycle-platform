import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_patient/connected_health_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/patient_journey_driver.dart';
import 'support/patient_journey_fixtures.dart';
import 'support/patient_journey_harness.dart';
import 'support/patient_journey_suite.dart';

void main() {
  final virtualNow = DateTime.utc(2026, 9, 17, 9);

  testWidgets('observed home route preserves value and provenance', (
    tester,
  ) async {
    final harness = PatientJourneyHarness(
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
    await harness.pumpHome(tester);
    await PatientJourneyDriver(tester).tapText('Connected Health');

    expect(find.text('SpO2'), findsOneWidget);
    expect(find.text('98.0 %'), findsOneWidget);
    expect(find.textContaining('Health Connect'), findsWidgets);
  });

  testWidgets('missing home route does not invent zero', (tester) async {
    final harness = PatientJourneyHarness(
      virtualNow: virtualNow,
      events: const <HealthEvent>[],
      authenticationOutcomes: const <bool>[true],
    );
    await harness.pumpHome(tester);
    await PatientJourneyDriver(tester).tapText('Connected Health');

    expect(find.text('No connected health data yet.'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('conflicting home route preserves conflict and provenance', (
    tester,
  ) async {
    final harness = PatientJourneyHarness(
      virtualNow: virtualNow,
      events: p002Events(virtualNow),
      authenticationOutcomes: const <bool>[true],
    );
    await harness.pumpHome(tester);
    await PatientJourneyDriver(tester).tapText('Connected Health');
    await tester.scrollUntilVisible(find.text('SpO2'), 300);

    expect(find.text('Sources conflict'), findsWidgets);
    expect(find.textContaining('Health Connect + HealthKit'), findsOneWidget);
    expect(find.text('94.5 %'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('stale direct production widget remains explicit', (
    tester,
  ) async {
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

    expect(find.text('Data stale'), findsWidgets);
    expect(find.textContaining('Health Connect'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('suite normalizes all Connected Health states', (tester) async {
    final results = await runConnectedHealthJourneys(tester);

    expect(results.map((result) => result.scenario.id), <String>[
      'connected-health-observed-provenance-home',
      'connected-health-missing-home',
      'connected-health-conflicting-home',
      'connected-health-stale-direct-widget',
    ]);
    expect(results.expand((result) => result.findings), isEmpty);
  });
}
