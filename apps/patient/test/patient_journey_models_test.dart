import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support/patient_journey_models.dart';

const int _seed = 20260917;
final DateTime _virtualNow = DateTime.utc(2026, 9, 17, 9);

typedef _DetectorCase = ({
  PatientJourneyObservation observation,
  String category,
  PatientJourneySeverity severity,
  String reasonCode,
});

PatientJourneyScenario _scenario({
  String id = 'journey-a',
  PatientJourneyFamily family = PatientJourneyFamily.todayComprehensionSurface,
  List<String> actions = const <String>['open-home'],
  List<String> assertions = const <String>['today-visible'],
}) => PatientJourneyScenario(
  id: id,
  schemaVersion: 1,
  seed: _seed,
  virtualNow: _virtualNow,
  fixtureId: 'P-001',
  locale: 'en',
  family: family,
  actions: actions,
  assertions: assertions,
);

PatientJourneyResult _result(String id) {
  final scenario = _scenario(id: id);
  return PatientJourneyResult(
    scenario: scenario,
    observation: const PatientJourneyObservation(
      surfaceReached: 'today',
      satisfiedAssertions: <String>['today-visible'],
      actionCount: 1,
    ),
    findings: const <PatientJourneyFinding>[],
    coverageLabels: const <String>{
      'family:todayComprehensionSurface',
      'fixture:P-001',
      'control:positive',
    },
  );
}

void main() {
  group('PatientJourneyScenario', () {
    test('scenario requires stable ids and UTC virtual time', () {
      expect(
        () => PatientJourneyScenario(
          id: '',
          schemaVersion: 1,
          seed: _seed,
          virtualNow: _virtualNow,
          fixtureId: 'P-001',
          locale: 'en',
          family: PatientJourneyFamily.todayComprehensionSurface,
          actions: const <String>['open-home'],
          assertions: const <String>['today-visible'],
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate action ids', () {
      expect(
        () => _scenario(actions: const <String>['open-home', 'open-home']),
        throwsArgumentError,
      );
    });

    test('rejects non-UTC virtual time', () {
      expect(
        () => PatientJourneyScenario(
          id: 'journey-a',
          schemaVersion: 1,
          seed: _seed,
          virtualNow: DateTime(2026, 9, 17, 9),
          fixtureId: 'P-001',
          locale: 'en',
          family: PatientJourneyFamily.todayComprehensionSurface,
          actions: const <String>['open-home'],
          assertions: const <String>['today-visible'],
        ),
        throwsArgumentError,
      );
    });

    test('rejects unsupported schema version', () {
      expect(
        () => PatientJourneyScenario(
          id: 'journey-a',
          schemaVersion: 2,
          seed: _seed,
          virtualNow: _virtualNow,
          fixtureId: 'P-001',
          locale: 'en',
          family: PatientJourneyFamily.todayComprehensionSurface,
          actions: const <String>['open-home'],
          assertions: const <String>['today-visible'],
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative observation counters', () {
      expect(
        () => PatientJourneyObservation(actionCount: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('PatientJourneyDetector', () {
    test('maps normalized failures to exact severities and reason codes', () {
      const cases = <_DetectorCase>[
        (
          observation: PatientJourneyObservation(
            privacyCoverVisible: true,
            sensitiveMarkerVisible: true,
          ),
          category: 'sensitive_content_exposed_while_locked',
          severity: PatientJourneySeverity.s4,
          reasonCode: 'locked_sensitive_marker_visible',
        ),
        (
          observation: PatientJourneyObservation(privacyCoverBypassed: true),
          category: 'privacy_cover_bypass',
          severity: PatientJourneySeverity.s4,
          reasonCode: 'privacy_cover_bypassed',
        ),
        (
          observation: PatientJourneyObservation(missingDisplayedAsZero: true),
          category: 'missing_data_invented_as_zero',
          severity: PatientJourneySeverity.s4,
          reasonCode: 'missing_displayed_as_zero',
        ),
        (
          observation: PatientJourneyObservation(
            conflictDisplayedAsCertain: true,
          ),
          category: 'conflict_collapsed_to_certainty',
          severity: PatientJourneySeverity.s4,
          reasonCode: 'conflict_displayed_as_certain',
        ),
        (
          observation: PatientJourneyObservation(coreJourneyBlocked: true),
          category: 'core_journey_blocked',
          severity: PatientJourneySeverity.s3,
          reasonCode: 'core_journey_blocked',
        ),
        (
          observation: PatientJourneyObservation(
            executionFailureCode: 'route-unavailable',
          ),
          category: 'core_journey_blocked',
          severity: PatientJourneySeverity.s3,
          reasonCode: 'route-unavailable',
        ),
        (
          observation: PatientJourneyObservation(
            recoveryAffordanceVisible: false,
          ),
          category: 'recovery_affordance_missing',
          severity: PatientJourneySeverity.s3,
          reasonCode: 'recovery_affordance_missing',
        ),
        (
          observation: PatientJourneyObservation(persistenceMatched: false),
          category: 'persistence_mismatch',
          severity: PatientJourneySeverity.s3,
          reasonCode: 'persistence_mismatch',
        ),
        (
          observation: PatientJourneyObservation(auditMatched: false),
          category: 'audit_mismatch',
          severity: PatientJourneySeverity.s3,
          reasonCode: 'audit_mismatch',
        ),
        (
          observation: PatientJourneyObservation(timelineExpected: true),
          category: 'timeline_retrieval_failure',
          severity: PatientJourneySeverity.s3,
          reasonCode: 'timeline_not_retrieved',
        ),
        (
          observation: PatientJourneyObservation(calendarExpected: true),
          category: 'calendar_retrieval_failure',
          severity: PatientJourneySeverity.s3,
          reasonCode: 'calendar_not_retrieved',
        ),
        (
          observation: PatientJourneyObservation(
            connectedHealthStateMatched: false,
          ),
          category: 'connected_health_state_mismatch',
          severity: PatientJourneySeverity.s3,
          reasonCode: 'connected_health_state_mismatch',
        ),
        (
          observation: PatientJourneyObservation(
            malformedReasonCode: 'duplicate-action-id',
          ),
          category: 'malformed_input',
          severity: PatientJourneySeverity.s3,
          reasonCode: 'duplicate-action-id',
        ),
      ];

      for (final testCase in cases) {
        final result = PatientJourneyDetector().evaluate(
          scenario: _scenario(),
          observation: testCase.observation,
          coverageLabels: const <String>{'control:negative'},
        );
        expect(result.findings, hasLength(1));
        expect(result.findings.single.category, testCase.category);
        expect(result.findings.single.severity, testCase.severity);
        expect(result.findings.single.reasonCode, testCase.reasonCode);
      }
    });

    test('locked sensitive content is an S4 negative control', () {
      final scenario = PatientJourneyScenario(
        id: 'privacy-negative-control',
        schemaVersion: 1,
        seed: _seed,
        virtualNow: _virtualNow,
        fixtureId: 'P-005',
        locale: 'en',
        family: PatientJourneyFamily.privacyLifecycleRelock,
        actions: const <String>['pause-app'],
        assertions: const <String>['privacy-no-sensitive-content'],
      );
      final result = PatientJourneyDetector().evaluate(
        scenario: scenario,
        observation: const PatientJourneyObservation(
          privacyCoverVisible: true,
          sensitiveMarkerVisible: true,
        ),
        coverageLabels: const <String>{'control:negative'},
      );
      expect(result.findings.single.severity, PatientJourneySeverity.s4);
      expect(result.passed, isFalse);
    });

    test('soft metrics alone do not produce findings', () {
      final result = PatientJourneyDetector().evaluate(
        scenario: _scenario(),
        observation: const PatientJourneyObservation(
          actionCount: 99,
          navigationCount: 99,
          recoveryCount: 99,
        ),
        coverageLabels: const <String>{'control:positive'},
      );
      expect(result.findings, isEmpty);
      expect(result.passed, isTrue);
    });
  });

  group('PatientJourneyReportBuilder', () {
    test('report JSON is byte stable independent of input result order', () {
      final builder = PatientJourneyReportBuilder(
        seed: _seed,
        virtualNow: _virtualNow,
      );
      final resultA = _result('journey-a');
      final resultB = _result('journey-b');
      final a = builder.build(
        results: <PatientJourneyResult>[resultB, resultA],
      );
      final b = builder.build(
        results: <PatientJourneyResult>[resultA, resultB],
      );
      expect(canonicalPatientJourneyJson(a), canonicalPatientJourneyJson(b));
    });

    test('rejects duplicate journey ids', () {
      final builder = PatientJourneyReportBuilder(
        seed: _seed,
        virtualNow: _virtualNow,
      );
      expect(
        () => builder.build(
          results: <PatientJourneyResult>[
            _result('duplicate'),
            _result('duplicate'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('emits one sorted S3 finding for every coverage gap', () {
      final report = PatientJourneyReportBuilder(
        seed: _seed,
        virtualNow: _virtualNow,
      ).build(results: <PatientJourneyResult>[_result('journey-a')]);
      final expectedMissing = PatientJourneyCoverage.mandatoryLabels.difference(
        _result('journey-a').coverageLabels,
      );
      final coverageFindings = report.findings
          .where((finding) => finding.category == 'coverage_gap')
          .toList();

      expect(coverageFindings, hasLength(expectedMissing.length));
      expect(
        coverageFindings.map((finding) => finding.reasonCode),
        expectedMissing.map((label) => 'coverage_gap:$label').toList()..sort(),
      );
      expect(
        coverageFindings.every(
          (finding) => finding.severity == PatientJourneySeverity.s3,
        ),
        isTrue,
      );
      expect(report.passed, isFalse);
    });

    test('canonical report JSON round-trips', () {
      final report = PatientJourneyReport(
        schemaVersion: 1,
        seed: _seed,
        virtualNow: _virtualNow,
        syntheticEvidenceOnly: true,
        results: const <PatientJourneyResult>[],
        findings: const <PatientJourneyFinding>[],
        coverage: const PatientJourneyCoverage(
          configured: 0,
          evaluated: 0,
          passed: 0,
          failed: 0,
          malformed: 0,
          labels: <String, int>{},
        ),
        actionCount: 0,
        navigationCount: 0,
        recoveryCount: 0,
      );
      final first = canonicalPatientJourneyJson(report);
      final decoded = Map<String, Object?>.from(
        jsonDecode(first) as Map<Object?, Object?>,
      );
      final restored = PatientJourneyReport.fromJson(decoded);
      expect(canonicalPatientJourneyJson(restored), first);
    });
  });
}
