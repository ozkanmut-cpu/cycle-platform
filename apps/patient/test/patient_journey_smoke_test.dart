import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/patient_journey_harness.dart';
import 'support/patient_journey_models.dart';
import 'support/patient_journey_suite.dart';

void main() {
  testWidgets('canonical Patient journey evidence is byte stable', (
    tester,
  ) async {
    final firstReport = await runCanonicalPatientJourneySuite(
      tester,
      seed: 20260917,
    );
    final firstJson = canonicalPatientJourneyJson(firstReport);

    await clearPatientJourneyWidgetTree(tester);

    final secondReport = await runCanonicalPatientJourneySuite(
      tester,
      seed: 20260917,
    );
    final secondJson = canonicalPatientJourneyJson(secondReport);

    expect(secondJson, firstJson);
    expect(secondReport.passed, isTrue, reason: secondReport.failureSummary);
    final missingLabels = PatientJourneyCoverage.mandatoryLabels
        .where((label) => (secondReport.coverage.labels[label] ?? 0) <= 0)
        .toList();
    expect(missingLabels, isEmpty);
    expect(secondReport.syntheticEvidenceOnly, isTrue);
    expect(secondReport.coverage.failed, 0);
    expect(secondReport.coverage.malformed, 0);
    File('patient-journey-evidence.json').writeAsStringSync('$secondJson\n');

    await clearPatientJourneyWidgetTree(tester);
  });
}
