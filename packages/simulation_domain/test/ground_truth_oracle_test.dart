import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  group('GroundTruthOracle', () {
    test('detects semantic collapse with expected-vs-actual provenance', () {
      final instant = DateTime.utc(2026, 1, 2);
      final report = const GroundTruthOracle().evaluate(
        seed: 7,
        truth: [
          GroundTruthClaim(
            id: 'truth-missing',
            patientId: 'patient-1',
            signal: HealthSignalKind.symptomSeverity,
            observedAt: instant,
            expectedState: SyntheticDataState.missing,
            source: SyntheticSourceKind.manual,
          ),
          GroundTruthClaim(
            id: 'truth-conflict',
            patientId: 'patient-2',
            signal: HealthSignalKind.symptomSeverity,
            observedAt: instant,
            expectedState: SyntheticDataState.conflicting,
            source: SyntheticSourceKind.clinical,
            value: 3,
            conflictingValue: 7,
          ),
          GroundTruthClaim(
            id: 'truth-estimate',
            patientId: 'patient-3',
            signal: HealthSignalKind.weight,
            observedAt: instant,
            expectedState: SyntheticDataState.estimated,
            source: SyntheticSourceKind.wearable,
            value: 70,
          ),
        ],
        observed: [
          OracleObservation(
            id: 'observed-zero',
            patientId: 'patient-1',
            signal: HealthSignalKind.symptomSeverity,
            observedAt: instant,
            state: SyntheticDataState.known,
            source: SyntheticSourceKind.manual,
            value: 0,
          ),
          OracleObservation(
            id: 'observed-certain',
            patientId: 'patient-2',
            signal: HealthSignalKind.symptomSeverity,
            observedAt: instant,
            state: SyntheticDataState.known,
            source: SyntheticSourceKind.clinical,
            value: 3,
          ),
          OracleObservation(
            id: 'observed-known',
            patientId: 'patient-3',
            signal: HealthSignalKind.weight,
            observedAt: instant,
            state: SyntheticDataState.known,
            source: SyntheticSourceKind.wearable,
            value: 70,
          ),
        ],
      );

      expect(
          report.findings.map((f) => f.category),
          containsAll([
            OracleFindingCategory.missingCollapsedToKnown,
            OracleFindingCategory.conflictCollapsedToCertain,
            OracleFindingCategory.estimateCollapsedToKnown,
          ]));
      expect(report.findings.every((f) => f.observedAt.isUtc), isTrue);
      expect(report.findings.every((f) => f.expectedState != f.actualState),
          isTrue);
    });

    test('detects deterministic contradictions with provenance', () {
      final instant = DateTime.utc(2026, 2, 1);
      final report = const GroundTruthOracle().evaluate(
        seed: 8,
        truth: [
          GroundTruthClaim(
            id: 'truth-a',
            patientId: 'patient-1',
            signal: HealthSignalKind.weight,
            observedAt: instant,
            expectedState: SyntheticDataState.known,
            source: SyntheticSourceKind.manual,
            value: 70,
          ),
          GroundTruthClaim(
            id: 'truth-b',
            patientId: 'patient-1',
            signal: HealthSignalKind.weight,
            observedAt: instant,
            expectedState: SyntheticDataState.known,
            source: SyntheticSourceKind.clinical,
            value: 75,
          ),
        ],
        observed: const [],
      );
      expect(report.findings.single.category,
          OracleFindingCategory.truthContradiction);
      expect(report.findings.single.relatedTruthClaimId, 'truth-b');
    });

    test(
        'canonical oracle covers 100 patients and round-trips deterministically',
        () {
      const seed = 20260916;
      final cohort = const CohortGenerator().canonical(seed);
      final world = const SyntheticHealthWorldGenerator()
          .generate(cohort: cohort, seed: seed);
      final longitudinal = const LongitudinalSimulationGenerator().generate(
        cohort: cohort,
        healthWorld: world,
        seed: seed,
        years: 1,
      );
      final oracle = const GroundTruthOracle();
      final first = oracle.evaluateSimulation(
        cohort: cohort,
        healthWorld: world,
        longitudinal: longitudinal,
        seed: seed,
      );
      final second = oracle.evaluateSimulation(
        cohort: cohort,
        healthWorld: world,
        longitudinal: longitudinal,
        seed: seed,
      );

      expect(first.toNormalizedJson(), second.toNormalizedJson());
      expect(first.coverage.evaluatedPatients, 100);
      expect(first.patientIds.toSet().length, 100);
      expect(first.patientIds, orderedEquals([...first.patientIds]..sort()));
      expect(first.coverage.evaluatedEpochs, greaterThan(0));
      expect(first.coverage.missing, greaterThan(0));
      expect(first.coverage.estimated, greaterThan(0));
      expect(first.coverage.conflicting, greaterThan(0));
      expect(first.coverage.temporalChanges, greaterThan(0));
      expect(first.coverage.recoveries, greaterThan(0));
      expect(first.coverage.sourceTransitions, greaterThan(0));
      final decoded =
          (jsonDecode(first.toNormalizedJson()) as Map).cast<String, Object?>();
      final restored = GroundTruthReport.fromJson(decoded);
      expect(restored.toNormalizedJson(), first.toNormalizedJson());
    });

    test('temporal truth preserves drift step recovery and regression', () {
      final cohort = const CohortGenerator().canonical(11);
      final world = const SyntheticHealthWorldGenerator()
          .generate(cohort: cohort, seed: 11);
      final longitudinal = const LongitudinalSimulationGenerator().generate(
        cohort: cohort,
        healthWorld: world,
        seed: 11,
        years: 1,
      );
      final report = const GroundTruthOracle().evaluateSimulation(
        cohort: cohort,
        healthWorld: world,
        longitudinal: longitudinal,
        seed: 11,
      );
      final patterns = report.temporalTruth.map((e) => e.pattern).toSet();
      expect(
          patterns,
          containsAll([
            LongitudinalPattern.stable,
            LongitudinalPattern.drift,
            LongitudinalPattern.stepChange,
            LongitudinalPattern.recovery,
            LongitudinalPattern.regression,
          ]));
    });

    test('malformed bundles fail safely', () {
      expect(
        () => GroundTruthReport.fromJson({
          'schemaVersion': groundTruthOracleSchemaVersion + 1,
          'seed': 1,
          'patientIds': <Object?>[],
          'findings': <Object?>[],
          'temporalTruth': <Object?>[],
          'coverage': <String, Object?>{},
        }),
        throwsFormatException,
      );
      expect(
        () => const GroundTruthOracle().evaluate(
          seed: 1,
          truth: [
            GroundTruthClaim(
              id: '',
              patientId: 'patient-1',
              signal: HealthSignalKind.weight,
              observedAt: DateTime.utc(2026),
              expectedState: SyntheticDataState.known,
              source: SyntheticSourceKind.manual,
              value: 70,
            ),
          ],
          observed: const [],
        ),
        throwsArgumentError,
      );
    });
  });
}
