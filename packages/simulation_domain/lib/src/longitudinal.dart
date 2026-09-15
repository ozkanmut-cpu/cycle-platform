import 'dart:convert';

import 'cohort.dart';
import 'health_world.dart';
import 'random.dart';

const int longitudinalSimulationSchemaVersion = 1;

enum LongitudinalPattern { stable, drift, stepChange, recovery, regression }

class LongitudinalEpoch {
  const LongitudinalEpoch({
    required this.id,
    required this.patientId,
    required this.startsAt,
    required this.endsAt,
    required this.pattern,
    required this.state,
    required this.source,
    this.value,
    this.conflictingValue,
  });

  final String id;
  final String patientId;
  final DateTime startsAt;
  final DateTime endsAt;
  final LongitudinalPattern pattern;
  final SyntheticDataState state;
  final SyntheticSourceKind source;
  final num? value;
  final num? conflictingValue;

  void validate() {
    if (id.trim().isEmpty || patientId.trim().isEmpty) {
      throw ArgumentError('Longitudinal epoch IDs must not be empty');
    }
    if (!startsAt.isUtc || !endsAt.isUtc || !endsAt.isAfter(startsAt)) {
      throw ArgumentError('Longitudinal epochs require ordered UTC bounds');
    }
    if (state == SyntheticDataState.missing) {
      if (value != null || conflictingValue != null) {
        throw ArgumentError('Missing longitudinal epochs cannot contain values');
      }
    } else if (value == null) {
      throw ArgumentError('Non-missing longitudinal epochs require a value');
    }
    if (state == SyntheticDataState.conflicting) {
      if (conflictingValue == null || conflictingValue == value) {
        throw ArgumentError('Conflicting epochs require two distinct values');
      }
    } else if (conflictingValue != null) {
      throw ArgumentError('Only conflicting epochs have a second value');
    }
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'patientId': patientId,
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'pattern': pattern.name,
        'state': state.name,
        'source': source.name,
        if (value != null) 'value': value,
        if (conflictingValue != null) 'conflictingValue': conflictingValue,
      };

  factory LongitudinalEpoch.fromJson(Map<String, Object?> json) {
    final epoch = LongitudinalEpoch(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String).toUtc(),
      endsAt: DateTime.parse(json['endsAt'] as String).toUtc(),
      pattern: _enumByName(LongitudinalPattern.values, json['pattern'], 'pattern'),
      state: _enumByName(SyntheticDataState.values, json['state'], 'state'),
      source: _enumByName(SyntheticSourceKind.values, json['source'], 'source'),
      value: json['value'] as num?,
      conflictingValue: json['conflictingValue'] as num?,
    );
    epoch.validate();
    return epoch;
  }
}

class LongitudinalPatientTrajectory {
  const LongitudinalPatientTrajectory({
    required this.patientId,
    required this.epochs,
  });

  final String patientId;
  final List<LongitudinalEpoch> epochs;

  void validate() {
    if (patientId.trim().isEmpty || epochs.isEmpty) {
      throw ArgumentError('Longitudinal trajectory requires patient and epochs');
    }
    final ids = <String>{};
    DateTime? previousEnd;
    for (final epoch in epochs) {
      epoch.validate();
      if (epoch.patientId != patientId) {
        throw ArgumentError('Trajectory contains another patient');
      }
      if (!ids.add(epoch.id)) throw ArgumentError('Epoch IDs must be unique');
      if (previousEnd != null && epoch.startsAt.isBefore(previousEnd)) {
        throw ArgumentError('Longitudinal epochs cannot overlap');
      }
      previousEnd = epoch.endsAt;
    }
  }

  Map<String, Object?> toJson() => {
        'patientId': patientId,
        'epochs': epochs.map((item) => item.toJson()).toList(),
      };

  factory LongitudinalPatientTrajectory.fromJson(Map<String, Object?> json) {
    final trajectory = LongitudinalPatientTrajectory(
      patientId: json['patientId'] as String,
      epochs: (json['epochs'] as List)
          .map((item) => LongitudinalEpoch.fromJson(
                (item as Map).cast<String, Object?>(),
              ))
          .toList(),
    );
    trajectory.validate();
    return trajectory;
  }
}

class LongitudinalSimulation {
  const LongitudinalSimulation({
    required this.seed,
    required this.startedAt,
    required this.years,
    required this.trajectories,
  });

  final int seed;
  final DateTime startedAt;
  final int years;
  final List<LongitudinalPatientTrajectory> trajectories;

  void validate({SimulationCohort? cohort}) {
    if (!startedAt.isUtc) throw ArgumentError('Longitudinal start must be UTC');
    if (![1, 3, 5].contains(years)) throw ArgumentError.value(years, 'years');
    final ids = trajectories.map((item) => item.patientId).toSet();
    if (ids.length != trajectories.length) {
      throw ArgumentError('Duplicate longitudinal patient trajectories');
    }
    for (final trajectory in trajectories) {
      trajectory.validate();
    }
    if (cohort != null) {
      final cohortIds = cohort.patients.map((item) => item.id).toSet();
      if (ids.length != cohortIds.length || !ids.containsAll(cohortIds)) {
        throw ArgumentError(
          'Longitudinal simulation must cover every cohort patient',
        );
      }
    }
  }

  Map<String, Object?> coverageSummary() {
    final epochs = trajectories.expand((item) => item.epochs).toList();
    final result = <String, Object?>{
      'patients': trajectories.length,
      'years': years,
      'epochs': epochs.length,
    };
    for (final pattern in LongitudinalPattern.values) {
      result[pattern.name] =
          epochs.where((item) => item.pattern == pattern).length;
    }
    for (final state in SyntheticDataState.values) {
      result[state.name] = epochs.where((item) => item.state == state).length;
    }
    var transitions = 0;
    for (final trajectory in trajectories) {
      for (var i = 1; i < trajectory.epochs.length; i++) {
        if (trajectory.epochs[i - 1].source != trajectory.epochs[i].source) {
          transitions++;
        }
      }
    }
    result['sourceTransitions'] = transitions;
    return result;
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': longitudinalSimulationSchemaVersion,
        'seed': seed,
        'startedAt': startedAt.toIso8601String(),
        'years': years,
        'trajectories': trajectories.map((item) => item.toJson()).toList(),
        'coverage': coverageSummary(),
      };

  String toNormalizedJson() => jsonEncode(toJson());

  factory LongitudinalSimulation.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != longitudinalSimulationSchemaVersion) {
      throw FormatException(
        'Unsupported longitudinal schemaVersion: ${json['schemaVersion']}',
      );
    }
    final simulation = LongitudinalSimulation(
      seed: json['seed'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      years: json['years'] as int,
      trajectories: (json['trajectories'] as List)
          .map((item) => LongitudinalPatientTrajectory.fromJson(
                (item as Map).cast<String, Object?>(),
              ))
          .toList(),
    );
    simulation.validate();
    return simulation;
  }
}

class LongitudinalSimulationGenerator {
  const LongitudinalSimulationGenerator();

  LongitudinalSimulation generate({
    required SimulationCohort cohort,
    required SyntheticHealthWorld healthWorld,
    required int seed,
    required int years,
  }) {
    cohort.validate();
    healthWorld.validate(cohort: cohort);
    if (![1, 3, 5].contains(years)) throw ArgumentError.value(years, 'years');
    final start = healthWorld.startedAt.toUtc();
    final trajectories = <LongitudinalPatientTrajectory>[];
    for (var index = 0; index < cohort.patients.length; index++) {
      final patient = cohort.patients[index];
      final random = DeterministicRandom(seed + 20000 + index);
      final epochs = <LongitudinalEpoch>[];
      final epochCount = years * 6;
      for (var sequence = 0; sequence < epochCount; sequence++) {
        final startsAt = DateTime.utc(
          start.year,
          start.month + sequence * 2,
          1,
        );
        final endsAt = DateTime.utc(
          start.year,
          start.month + (sequence + 1) * 2,
          1,
        );
        final pattern = LongitudinalPattern
            .values[(index + sequence) % LongitudinalPattern.values.length];
        final stateIndex = (index + sequence) % 17;
        final state = stateIndex == 0
            ? SyntheticDataState.missing
            : stateIndex == 1
                ? SyntheticDataState.estimated
                : stateIndex == 2
                    ? SyntheticDataState.conflicting
                    : SyntheticDataState.known;
        final source = SyntheticSourceKind.values[
            (index ~/ 3 + sequence) % SyntheticSourceKind.values.length];
        final base =
            (patient.symptomBurden + random.nextInt(3) - 1).clamp(0, 10);
        epochs.add(LongitudinalEpoch(
          id: '${patient.id}-long-${sequence.toString().padLeft(3, '0')}',
          patientId: patient.id,
          startsAt: startsAt,
          endsAt: endsAt,
          pattern: pattern,
          state: state,
          source: source,
          value: state == SyntheticDataState.missing ? null : base,
          conflictingValue: state == SyntheticDataState.conflicting
              ? (base == 10 ? 8 : base + 2)
              : null,
        ));
      }
      trajectories.add(
        LongitudinalPatientTrajectory(patientId: patient.id, epochs: epochs),
      );
    }
    final simulation = LongitudinalSimulation(
      seed: seed,
      startedAt: start,
      years: years,
      trajectories: trajectories,
    );
    simulation.validate(cohort: cohort);
    return simulation;
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, String field) {
  if (raw is! String) throw FormatException('$field must be a string');
  return values.firstWhere(
    (value) => value.name == raw,
    orElse: () => throw FormatException('Unknown $field: $raw'),
  );
}
