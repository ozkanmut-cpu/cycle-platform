import 'models.dart';
import 'runner.dart';

class FailureBundle {
  const FailureBundle({
    required this.schemaVersion,
    required this.targetInvariantId,
    required this.seed,
    required this.scenario,
    required this.actors,
    required this.events,
    required this.expectedSeverity,
    required this.expectedEvidence,
  });

  final int schemaVersion;
  final String targetInvariantId;
  final int seed;
  final SimulationScenario scenario;
  final List<SimulationActor> actors;
  final List<SimulationEvent> events;
  final InvariantSeverity expectedSeverity;
  final Map<String, Object?> expectedEvidence;

  ReplayMetadata get replay => ReplayMetadata(
        seed: seed,
        scenarioId: scenario.id,
        eventIds: events.map((event) => event.id).toList(growable: false),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'targetInvariantId': targetInvariantId,
        'seed': seed,
        'scenario': scenario.toJson(),
        'actors': actors.map((item) => item.toJson()).toList(growable: false),
        'events': events.map((item) => item.toJson()).toList(growable: false),
        'expectedSeverity': expectedSeverity.name,
        'expectedEvidence': expectedEvidence,
        'replay': replay.toJson(),
      };
}

class ReplayOutcome {
  const ReplayOutcome({required this.result, required this.target});

  final SimulationResult result;
  final InvariantResult target;

  bool matches(FailureBundle bundle) =>
      !target.passed &&
      target.id == bundle.targetInvariantId &&
      target.severity == bundle.expectedSeverity &&
      _deepEquals(target.evidence, bundle.expectedEvidence);
}

class ReplayEngine {
  const ReplayEngine();

  ReplayOutcome replay({
    required FailureBundle bundle,
    required SimulationInvariant invariant,
  }) {
    if (invariant.evaluate(const <SimulationEvent>[]).id !=
        bundle.targetInvariantId) {
      throw ArgumentError('Invariant does not match failure bundle target.');
    }

    final result = const SimulationRunner().run(
      seed: SimulationSeed(bundle.seed),
      scenario: bundle.scenario,
      actors: bundle.actors,
      eventFactory: (_) => List<SimulationEvent>.from(bundle.events),
      invariants: <SimulationInvariant>[invariant],
    );
    return ReplayOutcome(result: result, target: result.invariants.single);
  }
}

class ScenarioMinimizer {
  const ScenarioMinimizer();

  FailureBundle minimize({
    required FailureBundle bundle,
    required SimulationInvariant invariant,
  }) {
    final engine = const ReplayEngine();
    final original = engine.replay(bundle: bundle, invariant: invariant);
    if (!original.matches(bundle)) {
      throw StateError(
          'Target invariant is not reproducible before minimization.');
    }

    var current = List<SimulationEvent>.from(bundle.events);
    var index = 0;
    while (index < current.length) {
      final candidate = List<SimulationEvent>.from(current)..removeAt(index);
      final candidateBundle = FailureBundle(
        schemaVersion: bundle.schemaVersion,
        targetInvariantId: bundle.targetInvariantId,
        seed: bundle.seed,
        scenario: bundle.scenario,
        actors: bundle.actors,
        events: candidate,
        expectedSeverity: bundle.expectedSeverity,
        expectedEvidence: bundle.expectedEvidence,
      );
      final replay =
          engine.replay(bundle: candidateBundle, invariant: invariant);
      if (replay.matches(candidateBundle)) {
        current = candidate;
      } else {
        index += 1;
      }
    }

    return FailureBundle(
      schemaVersion: bundle.schemaVersion,
      targetInvariantId: bundle.targetInvariantId,
      seed: bundle.seed,
      scenario: bundle.scenario,
      actors: bundle.actors,
      events: current,
      expectedSeverity: bundle.expectedSeverity,
      expectedEvidence: bundle.expectedEvidence,
    );
  }
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final key in left.keys) {
      if (!right.containsKey(key) || !_deepEquals(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (!_deepEquals(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}
