import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  group('GroundTruthOracle', () {
    test('keeps hidden truth independent from observed state', () {
      final truth = GroundTruthClaim(
        id: 'truth-1',
        patientId: 'patient-1',
        signal: HealthSignalKind.symptomSeverity,
        observedAt: DateTime.utc(2026, 1, 1),
        expectedState: SyntheticDataState.missing,
      );
      final observed = OracleObservation(
        id: 'observed-1',
        patientId: 'patient-1',
        signal: HealthSignalKind.symptomSeverity,
        observedAt: DateTime.utc(2026, 1, 1),
        state: SyntheticDataState.known,
        value: 0,
      );

      final report = const GroundTruthOracle().evaluate(
        truth: [truth],
        observed: [observed],
      );

      expect(
        report.findings.map((finding) => finding.category),
        contains(OracleFindingCategory.missingCollapsedToZero),
      );
      expect(report.findings.single.truthClaimId, truth.id);
      expect(report.findings.single.observationId, observed.id);
    });

    test('detects a conflicting truth collapsed into certainty', () {
      final instant = DateTime.utc(2026, 1, 2);
      final report = const GroundTruthOracle().evaluate(
        truth: [
          GroundTruthClaim(
            id: 'truth-conflict',
            patientId: 'patient-1',
            signal: HealthSignalKind.symptomSeverity,
            observedAt: instant,
            expectedState: SyntheticDataState.conflicting,
            value: 3,
            conflictingValue: 7,
          ),
        ],
        observed: [
          OracleObservation(
            id: 'observed-certain',
            patientId: 'patient-1',
            signal: HealthSignalKind.symptomSeverity,
            observedAt: instant,
            state: SyntheticDataState.known,
            value: 3,
          ),
        ],
      );

      expect(
        report.findings.map((finding) => finding.category),
        contains(OracleFindingCategory.conflictCollapsedToCertain),
      );
    });
  });
}
