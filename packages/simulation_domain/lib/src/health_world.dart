import 'dart:convert';

import 'cohort.dart';
import 'personas.dart';
import 'random.dart';

const int healthWorldSchemaVersion = 1;

enum HealthSignalKind {
  heartRate,
  restingHeartRate,
  sleepDuration,
  stepCount,
  temperature,
  weight,
  symptomSeverity,
  bleeding,
}

enum SyntheticDataState { known, missing, estimated, conflicting }

enum SyntheticSourceKind { manual, wearable, clinical }

class SyntheticHealthObservation {
  const SyntheticHealthObservation({
    required this.id,
    required this.patientId,
    required this.kind,
    required this.observedAt,
    required this.state,
    required this.source,
    this.value,
    this.unit,
    this.conflictingValue,
  });

  final String id;
  final String patientId;
  final HealthSignalKind kind;
  final DateTime observedAt;
  final SyntheticDataState state;
  final SyntheticSourceKind source;
  final num? value;
  final String? unit;
  final num? conflictingValue;

  void validate() {
    if (id.trim().isEmpty || patientId.trim().isEmpty) {
      throw ArgumentError('Health observation IDs must not be empty');
    }
    if (!observedAt.isUtc) {
      throw ArgumentError('Health observations must use UTC timestamps');
    }
    if (state == SyntheticDataState.missing) {
      if (value != null || conflictingValue != null) {
        throw ArgumentError('Missing observations cannot contain values');
      }
    } else if (value == null) {
      throw ArgumentError('Known observations require a value');
    }
    if (state == SyntheticDataState.conflicting) {
      if (conflictingValue == null || conflictingValue == value) {
        throw ArgumentError('Conflicting observations require two values');
      }
    } else if (conflictingValue != null) {
      throw ArgumentError('Only conflicting observations have a second value');
    }
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'patientId': patientId,
        'kind': kind.name,
        'observedAt': observedAt.toUtc().toIso8601String(),
        'state': state.name,
        'source': source.name,
        if (value != null) 'value': value,
        if (unit != null) 'unit': unit,
        if (conflictingValue != null) 'conflictingValue': conflictingValue,
      };

  factory SyntheticHealthObservation.fromJson(Map<String, Object?> json) {
    final observation = SyntheticHealthObservation(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      kind: _enumByName(HealthSignalKind.values, json['kind'], 'kind'),
      observedAt: DateTime.parse(json['observedAt'] as String).toUtc(),
      state: _enumByName(SyntheticDataState.values, json['state'], 'state'),
      source: _enumByName(SyntheticSourceKind.values, json['source'], 'source'),
      value: json['value'] as num?,
      unit: json['unit'] as String?,
      conflictingValue: json['conflictingValue'] as num?,
    );
    observation.validate();
    return observation;
  }
}

class SyntheticPatientTimeline {
  const SyntheticPatientTimeline({
    required this.patientId,
    required this.observations,
  });

  final String patientId;
  final List<SyntheticHealthObservation> observations;

  void validate() {
    if (patientId.trim().isEmpty) throw ArgumentError('patientId is required');
    if (observations.isEmpty) {
      throw ArgumentError('Synthetic patient timeline cannot be empty');
    }
    final ids = <String>{};
    DateTime? previous;
    for (final observation in observations) {
      observation.validate();
      if (observation.patientId != patientId) {
        throw ArgumentError(
            'Timeline contains an observation for another patient');
      }
      if (!ids.add(observation.id)) {
        throw ArgumentError('Timeline observation IDs must be unique');
      }
      if (previous != null && observation.observedAt.isBefore(previous)) {
        throw ArgumentError(
            'Timeline observations must be chronologically ordered');
      }
      previous = observation.observedAt;
    }
  }

  Map<String, Object?> toJson() => {
        'patientId': patientId,
        'observations': observations.map((item) => item.toJson()).toList(),
      };

  factory SyntheticPatientTimeline.fromJson(Map<String, Object?> json) {
    final timeline = SyntheticPatientTimeline(
      patientId: json['patientId'] as String,
      observations: (json['observations'] as List)
          .map((item) => SyntheticHealthObservation.fromJson(
              (item as Map).cast<String, Object?>()))
          .toList(),
    );
    timeline.validate();
    return timeline;
  }
}

class SyntheticHealthWorld {
  const SyntheticHealthWorld({
    required this.seed,
    required this.startedAt,
    required this.days,
    required this.timelines,
  });

  final int seed;
  final DateTime startedAt;
  final int days;
  final List<SyntheticPatientTimeline> timelines;

  void validate({SimulationCohort? cohort}) {
    if (!startedAt.isUtc) throw ArgumentError('Health world start must be UTC');
    if (days <= 0) throw ArgumentError.value(days, 'days');
    final patientIds = timelines.map((item) => item.patientId).toSet();
    if (patientIds.length != timelines.length) {
      throw ArgumentError(
          'Health world cannot contain duplicate patient timelines');
    }
    for (final timeline in timelines) timeline.validate();
    if (cohort != null) {
      final cohortIds = cohort.patients.map((patient) => patient.id).toSet();
      if (patientIds.length != cohortIds.length ||
          !patientIds.containsAll(cohortIds)) {
        throw ArgumentError(
            'Health world must cover every cohort patient exactly once');
      }
    }
    final observations = timelines.expand((item) => item.observations);
    if (!observations.any((item) => item.state == SyntheticDataState.missing) ||
        !observations
            .any((item) => item.state == SyntheticDataState.estimated) ||
        !observations
            .any((item) => item.state == SyntheticDataState.conflicting)) {
      throw ArgumentError(
          'Health world must exercise missing, estimated and conflicting data');
    }
  }

  Map<String, Object?> coverageSummary() {
    final observations = timelines.expand((item) => item.observations).toList();
    int countState(SyntheticDataState state) =>
        observations.where((item) => item.state == state).length;
    int countSource(SyntheticSourceKind source) =>
        observations.where((item) => item.source == source).length;
    return {
      'patients': timelines.length,
      'observations': observations.length,
      'known': countState(SyntheticDataState.known),
      'missing': countState(SyntheticDataState.missing),
      'estimated': countState(SyntheticDataState.estimated),
      'conflicting': countState(SyntheticDataState.conflicting),
      'manual': countSource(SyntheticSourceKind.manual),
      'wearable': countSource(SyntheticSourceKind.wearable),
      'clinical': countSource(SyntheticSourceKind.clinical),
      'signalKinds': observations.map((item) => item.kind.name).toSet().length,
    };
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': healthWorldSchemaVersion,
        'seed': seed,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'days': days,
        'timelines': timelines.map((item) => item.toJson()).toList(),
        'coverage': coverageSummary(),
      };

  String toNormalizedJson() => jsonEncode(toJson());

  factory SyntheticHealthWorld.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != healthWorldSchemaVersion) {
      throw FormatException(
          'Unsupported health world schemaVersion: ${json['schemaVersion']}');
    }
    final world = SyntheticHealthWorld(
      seed: json['seed'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      days: json['days'] as int,
      timelines: (json['timelines'] as List)
          .map((item) => SyntheticPatientTimeline.fromJson(
              (item as Map).cast<String, Object?>()))
          .toList(),
    );
    world.validate();
    return world;
  }
}

class SyntheticHealthWorldGenerator {
  const SyntheticHealthWorldGenerator();

  SyntheticHealthWorld generate({
    required SimulationCohort cohort,
    required int seed,
    DateTime? startedAt,
    int days = 28,
  }) {
    cohort.validate();
    final start = (startedAt ?? DateTime.utc(2026, 1, 1)).toUtc();
    if (days <= 0) throw ArgumentError.value(days, 'days');
    final timelines = <SyntheticPatientTimeline>[];
    for (var index = 0; index < cohort.patients.length; index++) {
      timelines
          .add(_timeline(cohort.patients[index], seed, index, start, days));
    }
    final world = SyntheticHealthWorld(
      seed: seed,
      startedAt: start,
      days: days,
      timelines: timelines,
    );
    world.validate(cohort: cohort);
    return world;
  }

  SyntheticPatientTimeline _timeline(
    PatientPersona patient,
    int seed,
    int patientIndex,
    DateTime start,
    int days,
  ) {
    final random = DeterministicRandom(seed + 10000 + patientIndex);
    final observations = <SyntheticHealthObservation>[];
    var sequence = 0;
    for (var day = 0; day < days; day++) {
      final at = start.add(Duration(days: day, hours: 8));
      final sparseSkip =
          patient.core.loggingBehaviour == LoggingBehaviour.sparse &&
              day % 3 != 0;
      final prolongedMissing =
          patient.missingnessPattern == MissingnessPattern.prolonged &&
              day >= days ~/ 3 &&
              day < (days * 2) ~/ 3;
      if (sparseSkip || prolongedMissing) {
        observations.add(_observation(
          patient: patient,
          sequence: sequence++,
          kind: HealthSignalKind.symptomSeverity,
          at: at,
          state: SyntheticDataState.missing,
          source: SyntheticSourceKind.manual,
        ));
        continue;
      }

      final symptomState =
          patient.missingnessPattern == MissingnessPattern.conflicting &&
                  day % 11 == 0
              ? SyntheticDataState.conflicting
              : day % 19 == 0
                  ? SyntheticDataState.estimated
                  : SyntheticDataState.known;
      final symptom =
          (patient.symptomBurden + random.nextInt(3) - 1).clamp(0, 10);
      observations.add(_observation(
        patient: patient,
        sequence: sequence++,
        kind: HealthSignalKind.symptomSeverity,
        at: at,
        state: symptomState,
        source: SyntheticSourceKind.manual,
        value: symptom,
        unit: 'score',
        conflictingValue: symptomState == SyntheticDataState.conflicting
            ? (symptom + 2).clamp(0, 10)
            : null,
      ));

      if (patient.core.wearableUse != WearableUse.none) {
        observations.add(_observation(
          patient: patient,
          sequence: sequence++,
          kind: HealthSignalKind.restingHeartRate,
          at: at.add(const Duration(minutes: 5)),
          state: day % 17 == 0
              ? SyntheticDataState.estimated
              : SyntheticDataState.known,
          source: SyntheticSourceKind.wearable,
          value: 58 + random.nextInt(31),
          unit: 'bpm',
        ));
        observations.add(_observation(
          patient: patient,
          sequence: sequence++,
          kind: HealthSignalKind.sleepDuration,
          at: at.add(const Duration(minutes: 10)),
          state: SyntheticDataState.known,
          source: SyntheticSourceKind.wearable,
          value: 300 + random.nextInt(241),
          unit: 'min',
        ));
      }

      if (day % 7 == 0) {
        observations.add(_observation(
          patient: patient,
          sequence: sequence++,
          kind: HealthSignalKind.weight,
          at: at.add(const Duration(minutes: 20)),
          state: SyntheticDataState.known,
          source: SyntheticSourceKind.clinical,
          value: 50 + random.nextInt(61),
          unit: 'kg',
        ));
      }
    }
    observations.sort((left, right) {
      final byTime = left.observedAt.compareTo(right.observedAt);
      return byTime != 0 ? byTime : left.id.compareTo(right.id);
    });
    final timeline = SyntheticPatientTimeline(
      patientId: patient.id,
      observations: observations,
    );
    timeline.validate();
    return timeline;
  }

  SyntheticHealthObservation _observation({
    required PatientPersona patient,
    required int sequence,
    required HealthSignalKind kind,
    required DateTime at,
    required SyntheticDataState state,
    required SyntheticSourceKind source,
    num? value,
    String? unit,
    num? conflictingValue,
  }) {
    final observation = SyntheticHealthObservation(
      id: '${patient.id}-${sequence.toString().padLeft(4, '0')}-${kind.name}',
      patientId: patient.id,
      kind: kind,
      observedAt: at.toUtc(),
      state: state,
      source: source,
      value: value,
      unit: unit,
      conflictingValue: conflictingValue,
    );
    observation.validate();
    return observation;
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is! String) throw FormatException('$field must be a string');
  return values.firstWhere(
    (item) => item.name == value,
    orElse: () => throw FormatException('Unsupported $field: $value'),
  );
}
