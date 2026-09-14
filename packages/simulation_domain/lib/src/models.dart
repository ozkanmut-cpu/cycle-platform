import 'dart:convert';

enum SimulationActorKind { patient, partner, doctor, system }

enum InvariantSeverity { s0, s1, s2, s3, s4 }

class SimulationSeed {
  const SimulationSeed(this.value);

  final int value;

  Map<String, Object?> toJson() => <String, Object?>{'value': value};
}

class SimulationActor {
  const SimulationActor({
    required this.id,
    required this.kind,
    this.attributes = const <String, Object?>{},
  });

  final String id;
  final SimulationActorKind kind;
  final Map<String, Object?> attributes;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': kind.name,
        'attributes': attributes,
      };
}

class SimulationEvent {
  const SimulationEvent({
    required this.id,
    required this.type,
    required this.at,
    required this.sequence,
    required this.actorId,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final String type;
  final DateTime at;
  final int sequence;
  final String actorId;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'at': at.toUtc().toIso8601String(),
        'sequence': sequence,
        'actorId': actorId,
        'payload': payload,
      };
}

class SimulationScenario {
  const SimulationScenario({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name};
}

class InvariantResult {
  const InvariantResult({
    required this.id,
    required this.passed,
    required this.severity,
    required this.message,
    this.evidence = const <String, Object?>{},
  });

  final String id;
  final bool passed;
  final InvariantSeverity severity;
  final String message;
  final Map<String, Object?> evidence;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'passed': passed,
        'severity': severity.name,
        'message': message,
        'evidence': evidence,
      };
}

class ReplayMetadata {
  const ReplayMetadata({
    required this.seed,
    required this.scenarioId,
    required this.eventIds,
  });

  final int seed;
  final String scenarioId;
  final List<String> eventIds;

  Map<String, Object?> toJson() => <String, Object?>{
        'seed': seed,
        'scenarioId': scenarioId,
        'eventIds': eventIds,
      };
}

class SimulationResult {
  const SimulationResult({
    required this.runId,
    required this.seed,
    required this.scenario,
    required this.actors,
    required this.events,
    required this.invariants,
    required this.replay,
  });

  final String runId;
  final SimulationSeed seed;
  final SimulationScenario scenario;
  final List<SimulationActor> actors;
  final List<SimulationEvent> events;
  final List<InvariantResult> invariants;
  final ReplayMetadata replay;

  bool get passed => invariants.every((item) => item.passed);

  Map<String, Object?> toJson() => <String, Object?>{
        'runId': runId,
        'seed': seed.toJson(),
        'scenario': scenario.toJson(),
        'actors': actors.map((item) => item.toJson()).toList(growable: false),
        'events': events.map((item) => item.toJson()).toList(growable: false),
        'invariants':
            invariants.map((item) => item.toJson()).toList(growable: false),
        'replay': replay.toJson(),
        'passed': passed,
      };

  String toNormalizedJson() => jsonEncode(toJson());
}
