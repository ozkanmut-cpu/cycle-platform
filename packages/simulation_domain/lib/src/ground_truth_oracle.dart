import 'health_world.dart';

enum OracleFindingCategory {
  missingCollapsedToZero,
  conflictCollapsedToCertain,
}

class GroundTruthClaim {
  const GroundTruthClaim({
    required this.id,
    required this.patientId,
    required this.signal,
    required this.observedAt,
    required this.expectedState,
    this.value,
    this.conflictingValue,
  });

  final String id;
  final String patientId;
  final HealthSignalKind signal;
  final DateTime observedAt;
  final SyntheticDataState expectedState;
  final num? value;
  final num? conflictingValue;
}

class OracleObservation {
  const OracleObservation({
    required this.id,
    required this.patientId,
    required this.signal,
    required this.observedAt,
    required this.state,
    this.value,
    this.conflictingValue,
  });

  final String id;
  final String patientId;
  final HealthSignalKind signal;
  final DateTime observedAt;
  final SyntheticDataState state;
  final num? value;
  final num? conflictingValue;
}

class OracleFinding {
  const OracleFinding({
    required this.category,
    required this.truthClaimId,
    required this.observationId,
  });

  final OracleFindingCategory category;
  final String truthClaimId;
  final String observationId;
}

class GroundTruthReport {
  const GroundTruthReport({required this.findings});

  final List<OracleFinding> findings;
}

class GroundTruthOracle {
  const GroundTruthOracle();

  GroundTruthReport evaluate({
    required List<GroundTruthClaim> truth,
    required List<OracleObservation> observed,
  }) {
    final findings = <OracleFinding>[];
    for (final claim in truth) {
      for (final observation in observed) {
        if (!_matches(claim, observation)) continue;
        if (claim.expectedState == SyntheticDataState.missing &&
            observation.state == SyntheticDataState.known &&
            observation.value == 0) {
          findings.add(OracleFinding(
            category: OracleFindingCategory.missingCollapsedToZero,
            truthClaimId: claim.id,
            observationId: observation.id,
          ));
        }
        if (claim.expectedState == SyntheticDataState.conflicting &&
            observation.state == SyntheticDataState.known) {
          findings.add(OracleFinding(
            category: OracleFindingCategory.conflictCollapsedToCertain,
            truthClaimId: claim.id,
            observationId: observation.id,
          ));
        }
      }
    }
    return GroundTruthReport(findings: List.unmodifiable(findings));
  }

  bool _matches(GroundTruthClaim claim, OracleObservation observation) =>
      claim.patientId == observation.patientId &&
      claim.signal == observation.signal &&
      claim.observedAt.toUtc() == observation.observedAt.toUtc();
}
