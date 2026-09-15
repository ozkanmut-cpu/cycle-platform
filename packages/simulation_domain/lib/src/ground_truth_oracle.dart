import 'dart:convert';

import 'cohort.dart';
import 'health_world.dart';
import 'longitudinal.dart';

const int groundTruthOracleSchemaVersion = 1;

enum OracleFindingSeverity { warning, error }

enum OracleFindingCategory {
  missingCollapsedToKnown,
  conflictCollapsedToCertain,
  estimateCollapsedToKnown,
  truthContradiction,
}

class GroundTruthClaim {
  const GroundTruthClaim({
    required this.id,
    required this.patientId,
    required this.signal,
    required this.observedAt,
    required this.expectedState,
    required this.source,
    this.value,
    this.conflictingValue,
  });
  final String id;
  final String patientId;
  final HealthSignalKind signal;
  final DateTime observedAt;
  final SyntheticDataState expectedState;
  final SyntheticSourceKind source;
  final num? value;
  final num? conflictingValue;

  void validate() {
    if (id.trim().isEmpty || patientId.trim().isEmpty) {
      throw ArgumentError('Ground-truth IDs must not be empty');
    }
    if (!observedAt.isUtc) {
      throw ArgumentError('Ground truth must use UTC timestamps');
    }
    if (expectedState == SyntheticDataState.missing) {
      if (value != null || conflictingValue != null) {
        throw ArgumentError('Missing truth cannot contain values');
      }
    } else if (value == null) {
      throw ArgumentError('Non-missing truth requires a value');
    }
    if (expectedState == SyntheticDataState.conflicting) {
      if (conflictingValue == null || conflictingValue == value) {
        throw ArgumentError('Conflicting truth requires two values');
      }
    } else if (conflictingValue != null) {
      throw ArgumentError('Only conflicting truth has a second value');
    }
  }
}

class OracleObservation {
  const OracleObservation({
    required this.id,
    required this.patientId,
    required this.signal,
    required this.observedAt,
    required this.state,
    required this.source,
    this.value,
    this.conflictingValue,
  });
  final String id;
  final String patientId;
  final HealthSignalKind signal;
  final DateTime observedAt;
  final SyntheticDataState state;
  final SyntheticSourceKind source;
  final num? value;
  final num? conflictingValue;

  void validate() {
    if (id.trim().isEmpty || patientId.trim().isEmpty) {
      throw ArgumentError('Oracle observation IDs must not be empty');
    }
    if (!observedAt.isUtc) {
      throw ArgumentError('Oracle observations must use UTC timestamps');
    }
  }
}

class TemporalTruth {
  const TemporalTruth({
    required this.id,
    required this.patientId,
    required this.startsAt,
    required this.endsAt,
    required this.pattern,
    required this.state,
    required this.source,
  });
  final String id;
  final String patientId;
  final DateTime startsAt;
  final DateTime endsAt;
  final LongitudinalPattern pattern;
  final SyntheticDataState state;
  final SyntheticSourceKind source;

  Map<String, Object?> toJson() => {
        'id': id,
        'patientId': patientId,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'pattern': pattern.name,
        'state': state.name,
        'source': source.name,
      };

  factory TemporalTruth.fromJson(Map<String, Object?> json) => TemporalTruth(
        id: json['id'] as String,
        patientId: json['patientId'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String).toUtc(),
        endsAt: DateTime.parse(json['endsAt'] as String).toUtc(),
        pattern: _enumByName(LongitudinalPattern.values, json['pattern'], 'pattern'),
        state: _enumByName(SyntheticDataState.values, json['state'], 'state'),
        source: _enumByName(SyntheticSourceKind.values, json['source'], 'source'),
      );
}

class OracleFinding {
  const OracleFinding({
    required this.id,
    required this.severity,
    required this.category,
    required this.patientId,
    required this.signal,
    required this.observedAt,
    required this.truthClaimId,
    required this.expectedState,
    this.observationId,
    this.relatedTruthClaimId,
    this.actualState,
  });
  final String id;
  final OracleFindingSeverity severity;
  final OracleFindingCategory category;
  final String patientId;
  final HealthSignalKind signal;
  final DateTime observedAt;
  final String truthClaimId;
  final String? observationId;
  final String? relatedTruthClaimId;
  final SyntheticDataState expectedState;
  final SyntheticDataState? actualState;

  Map<String, Object?> toJson() => {
        'id': id,
        'severity': severity.name,
        'category': category.name,
        'patientId': patientId,
        'signal': signal.name,
        'observedAt': observedAt.toUtc().toIso8601String(),
        'truthClaimId': truthClaimId,
        if (observationId != null) 'observationId': observationId,
        if (relatedTruthClaimId != null)
          'relatedTruthClaimId': relatedTruthClaimId,
        'expectedState': expectedState.name,
        if (actualState != null) 'actualState': actualState!.name,
      };

  factory OracleFinding.fromJson(Map<String, Object?> json) => OracleFinding(
        id: json['id'] as String,
        severity: _enumByName(
            OracleFindingSeverity.values, json['severity'], 'severity'),
        category: _enumByName(
            OracleFindingCategory.values, json['category'], 'category'),
        patientId: json['patientId'] as String,
        signal: _enumByName(HealthSignalKind.values, json['signal'], 'signal'),
        observedAt: DateTime.parse(json['observedAt'] as String).toUtc(),
        truthClaimId: json['truthClaimId'] as String,
        observationId: json['observationId'] as String?,
        relatedTruthClaimId: json['relatedTruthClaimId'] as String?,
        expectedState: _enumByName(
            SyntheticDataState.values, json['expectedState'], 'expectedState'),
        actualState: json['actualState'] == null
            ? null
            : _enumByName(
                SyntheticDataState.values, json['actualState'], 'actualState'),
      );
}

class OracleCoverage {
  const OracleCoverage({
    required this.evaluatedPatients,
    required this.evaluatedEpochs,
    required this.missing,
    required this.estimated,
    required this.conflicting,
    required this.temporalChanges,
    required this.recoveries,
    required this.contradictions,
    required this.sourceTransitions,
  });
  final int evaluatedPatients;
  final int evaluatedEpochs;
  final int missing;
  final int estimated;
  final int conflicting;
  final int temporalChanges;
  final int recoveries;
  final int contradictions;
  final int sourceTransitions;

  Map<String, Object?> toJson() => {
        'evaluatedPatients': evaluatedPatients,
        'evaluatedEpochs': evaluatedEpochs,
        'missing': missing,
        'estimated': estimated,
        'conflicting': conflicting,
        'temporalChanges': temporalChanges,
        'recoveries': recoveries,
        'contradictions': contradictions,
        'sourceTransitions': sourceTransitions,
      };

  factory OracleCoverage.fromJson(Map<String, Object?> json) => OracleCoverage(
        evaluatedPatients: json['evaluatedPatients'] as int,
        evaluatedEpochs: json['evaluatedEpochs'] as int,
        missing: json['missing'] as int,
        estimated: json['estimated'] as int,
        conflicting: json['conflicting'] as int,
        temporalChanges: json['temporalChanges'] as int,
        recoveries: json['recoveries'] as int,
        contradictions: json['contradictions'] as int,
        sourceTransitions: json['sourceTransitions'] as int,
      );
}

class GroundTruthReport {
  const GroundTruthReport({
    required this.seed,
    required this.patientIds,
    required this.findings,
    required this.temporalTruth,
    required this.coverage,
  });
  final int seed;
  final List<String> patientIds;
  final List<OracleFinding> findings;
  final List<TemporalTruth> temporalTruth;
  final OracleCoverage coverage;

  Map<String, Object?> toJson() => {
        'schemaVersion': groundTruthOracleSchemaVersion,
        'seed': seed,
        'syntheticEvidenceOnly': true,
        'patientIds': patientIds,
        'findings': findings.map((item) => item.toJson()).toList(),
        'temporalTruth': temporalTruth.map((item) => item.toJson()).toList(),
        'coverage': coverage.toJson(),
      };

  String toNormalizedJson() => jsonEncode(toJson());

  factory GroundTruthReport.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != groundTruthOracleSchemaVersion) {
      throw FormatException(
          'Unsupported oracle schemaVersion: ${json['schemaVersion']}');
    }
    try {
      return GroundTruthReport(
        seed: json['seed'] as int,
        patientIds: (json['patientIds'] as List).cast<String>(),
        findings: (json['findings'] as List)
            .map((item) => OracleFinding.fromJson(
                (item as Map).cast<String, Object?>()))
            .toList(),
        temporalTruth: (json['temporalTruth'] as List)
            .map((item) => TemporalTruth.fromJson(
                (item as Map).cast<String, Object?>()))
            .toList(),
        coverage: OracleCoverage.fromJson(
            (json['coverage'] as Map).cast<String, Object?>()),
      );
    } on TypeError catch (error) {
      throw FormatException('Malformed oracle report: $error');
    }
  }
}

class GroundTruthOracle {
  const GroundTruthOracle();

  GroundTruthReport evaluate({
    int seed = 0,
    required List<GroundTruthClaim> truth,
    required List<OracleObservation> observed,
  }) {
    for (final claim in truth) claim.validate();
    for (final observation in observed) observation.validate();
    final truthIds = <String>{};
    for (final claim in truth) {
      if (!truthIds.add(claim.id)) {
        throw ArgumentError('Ground-truth claim IDs must be unique');
      }
    }
    final findings = <OracleFinding>[];
    final sortedTruth = [...truth]..sort(_compareTruth);
    final sortedObserved = [...observed]..sort(_compareObserved);
    for (final claim in sortedTruth) {
      for (final observation in sortedObserved) {
        if (!_matches(claim, observation)) continue;
        final category = _collapseCategory(claim, observation);
        if (category != null) {
          findings.add(_finding(
            index: findings.length,
            category: category,
            claim: claim,
            observation: observation,
          ));
        }
      }
    }
    for (var i = 0; i < sortedTruth.length; i++) {
      for (var j = i + 1; j < sortedTruth.length; j++) {
        final left = sortedTruth[i];
        final right = sortedTruth[j];
        if (!_samePoint(left, right)) continue;
        if (left.expectedState == SyntheticDataState.known &&
            right.expectedState == SyntheticDataState.known &&
            left.value != right.value) {
          findings.add(OracleFinding(
            id: _findingId(findings.length, left.patientId,
                OracleFindingCategory.truthContradiction),
            severity: OracleFindingSeverity.error,
            category: OracleFindingCategory.truthContradiction,
            patientId: left.patientId,
            signal: left.signal,
            observedAt: left.observedAt,
            truthClaimId: left.id,
            relatedTruthClaimId: right.id,
            expectedState: left.expectedState,
          ));
        }
      }
    }
    findings.sort((a, b) => a.id.compareTo(b.id));
    final patients = sortedTruth.map((item) => item.patientId).toSet().toList()
      ..sort();
    return GroundTruthReport(
      seed: seed,
      patientIds: List.unmodifiable(patients),
      findings: List.unmodifiable(findings),
      temporalTruth: const [],
      coverage: OracleCoverage(
        evaluatedPatients: patients.length,
        evaluatedEpochs: 0,
        missing: sortedTruth
            .where((item) => item.expectedState == SyntheticDataState.missing)
            .length,
        estimated: sortedTruth
            .where((item) => item.expectedState == SyntheticDataState.estimated)
            .length,
        conflicting: sortedTruth
            .where((item) => item.expectedState == SyntheticDataState.conflicting)
            .length,
        temporalChanges: 0,
        recoveries: 0,
        contradictions: findings
            .where((item) =>
                item.category == OracleFindingCategory.truthContradiction)
            .length,
        sourceTransitions: 0,
      ),
    );
  }

  GroundTruthReport evaluateSimulation({
    required SimulationCohort cohort,
    required SyntheticHealthWorld healthWorld,
    required LongitudinalSimulation longitudinal,
    required int seed,
  }) {
    cohort.validate();
    healthWorld.validate(cohort: cohort);
    longitudinal.validate(cohort: cohort);
    final expected = cohort.patients.map((item) => item.id).toList()..sort();
    final worldIds = healthWorld.timelines.map((item) => item.patientId).toList()
      ..sort();
    final longitudinalIds =
        longitudinal.trajectories.map((item) => item.patientId).toList()..sort();
    if (!_sameStrings(expected, worldIds) ||
        !_sameStrings(expected, longitudinalIds)) {
      throw ArgumentError('Oracle inputs must cover the canonical patients');
    }
    final temporal = longitudinal.trajectories
        .expand((trajectory) => trajectory.epochs.map((epoch) => TemporalTruth(
              id: 'truth-${epoch.id}',
              patientId: epoch.patientId,
              startsAt: epoch.startsAt.toUtc(),
              endsAt: epoch.endsAt.toUtc(),
              pattern: epoch.pattern,
              state: epoch.state,
              source: epoch.source,
            )))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final observations = healthWorld.timelines
        .expand((timeline) => timeline.observations)
        .toList();
    final epochs = longitudinal.trajectories
        .expand((trajectory) => trajectory.epochs)
        .toList();
    var transitions = 0;
    for (final trajectory in longitudinal.trajectories) {
      for (var i = 1; i < trajectory.epochs.length; i++) {
        if (trajectory.epochs[i - 1].source != trajectory.epochs[i].source) {
          transitions++;
        }
      }
    }
    return GroundTruthReport(
      seed: seed,
      patientIds: List.unmodifiable(expected),
      findings: const [],
      temporalTruth: List.unmodifiable(temporal),
      coverage: OracleCoverage(
        evaluatedPatients: expected.length,
        evaluatedEpochs: epochs.length,
        missing: observations
                .where((item) => item.state == SyntheticDataState.missing)
                .length +
            epochs
                .where((item) => item.state == SyntheticDataState.missing)
                .length,
        estimated: observations
                .where((item) => item.state == SyntheticDataState.estimated)
                .length +
            epochs
                .where((item) => item.state == SyntheticDataState.estimated)
                .length,
        conflicting: observations
                .where((item) => item.state == SyntheticDataState.conflicting)
                .length +
            epochs
                .where((item) => item.state == SyntheticDataState.conflicting)
                .length,
        temporalChanges: epochs
            .where((item) =>
                item.pattern == LongitudinalPattern.drift ||
                item.pattern == LongitudinalPattern.stepChange ||
                item.pattern == LongitudinalPattern.regression)
            .length,
        recoveries: epochs
            .where((item) => item.pattern == LongitudinalPattern.recovery)
            .length,
        contradictions: 0,
        sourceTransitions: transitions,
      ),
    );
  }

  OracleFindingCategory? _collapseCategory(
      GroundTruthClaim claim, OracleObservation observation) {
    if (claim.expectedState == SyntheticDataState.missing &&
        observation.state == SyntheticDataState.known) {
      return OracleFindingCategory.missingCollapsedToKnown;
    }
    if (claim.expectedState == SyntheticDataState.conflicting &&
        observation.state == SyntheticDataState.known) {
      return OracleFindingCategory.conflictCollapsedToCertain;
    }
    if (claim.expectedState == SyntheticDataState.estimated &&
        observation.state == SyntheticDataState.known) {
      return OracleFindingCategory.estimateCollapsedToKnown;
    }
    return null;
  }

  OracleFinding _finding({
    required int index,
    required OracleFindingCategory category,
    required GroundTruthClaim claim,
    required OracleObservation observation,
  }) =>
      OracleFinding(
        id: _findingId(index, claim.patientId, category),
        severity: OracleFindingSeverity.error,
        category: category,
        patientId: claim.patientId,
        signal: claim.signal,
        observedAt: claim.observedAt,
        truthClaimId: claim.id,
        observationId: observation.id,
        expectedState: claim.expectedState,
        actualState: observation.state,
      );

  bool _matches(GroundTruthClaim claim, OracleObservation observation) =>
      claim.patientId == observation.patientId &&
      claim.signal == observation.signal &&
      claim.observedAt == observation.observedAt;

  bool _samePoint(GroundTruthClaim left, GroundTruthClaim right) =>
      left.patientId == right.patientId &&
      left.signal == right.signal &&
      left.observedAt == right.observedAt;
}

int _compareTruth(GroundTruthClaim a, GroundTruthClaim b) {
  final patient = a.patientId.compareTo(b.patientId);
  if (patient != 0) return patient;
  final time = a.observedAt.compareTo(b.observedAt);
  if (time != 0) return time;
  final signal = a.signal.name.compareTo(b.signal.name);
  return signal != 0 ? signal : a.id.compareTo(b.id);
}

int _compareObserved(OracleObservation a, OracleObservation b) {
  final patient = a.patientId.compareTo(b.patientId);
  if (patient != 0) return patient;
  final time = a.observedAt.compareTo(b.observedAt);
  if (time != 0) return time;
  final signal = a.signal.name.compareTo(b.signal.name);
  return signal != 0 ? signal : a.id.compareTo(b.id);
}

String _findingId(int index, String patientId, OracleFindingCategory category) =>
    'oracle-${index.toString().padLeft(6, '0')}-$patientId-${category.name}';

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, String field) {
  if (raw is! String) throw FormatException('$field must be a string');
  return values.firstWhere(
    (value) => value.name == raw,
    orElse: () => throw FormatException('Unknown $field: $raw'),
  );
}
