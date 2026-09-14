import 'models.dart';

typedef SimulationEventFactory = List<SimulationEvent> Function(int seed);

abstract class SimulationInvariant {
  const SimulationInvariant();

  InvariantResult evaluate(List<SimulationEvent> events);
}

class MissingIsNotZeroInvariant extends SimulationInvariant {
  const MissingIsNotZeroInvariant();

  @override
  InvariantResult evaluate(List<SimulationEvent> events) {
    final violations = events
        .where((event) =>
            event.type == 'dataMissing' && event.payload['value'] == 0)
        .map((event) => event.id)
        .toList(growable: false);
    return InvariantResult(
      id: 'missing-is-not-zero',
      passed: violations.isEmpty,
      severity: InvariantSeverity.s4,
      message: violations.isEmpty
          ? 'Missing observations remain unknown.'
          : 'Missing observations were represented as zero.',
      evidence: <String, Object?>{'violatingEventIds': violations},
    );
  }
}

class PermissionRevocationInvariant extends SimulationInvariant {
  const PermissionRevocationInvariant();

  @override
  InvariantResult evaluate(List<SimulationEvent> events) {
    final revokedAt = <String, DateTime>{};
    final violations = <String>[];

    for (final event in events) {
      final category = event.payload['category'];
      if (category is! String) {
        continue;
      }
      final key = '${event.actorId}:$category';
      if (event.type == 'permissionRevoked') {
        revokedAt[key] = event.at;
      } else if (event.type == 'permissionRead') {
        final boundary = revokedAt[key];
        if (boundary != null && !event.at.isBefore(boundary)) {
          violations.add(event.id);
        }
      }
    }

    return InvariantResult(
      id: 'revocation-boundary',
      passed: violations.isEmpty,
      severity: InvariantSeverity.s4,
      message: violations.isEmpty
          ? 'No access occurred at or after revocation.'
          : 'Access occurred at or after revocation.',
      evidence: <String, Object?>{'violatingEventIds': violations},
    );
  }
}

class SimulationRunner {
  const SimulationRunner();

  SimulationResult run({
    required SimulationSeed seed,
    required SimulationScenario scenario,
    required List<SimulationActor> actors,
    required SimulationEventFactory eventFactory,
    List<SimulationInvariant> invariants = const <SimulationInvariant>[],
  }) {
    final events = List<SimulationEvent>.from(eventFactory(seed.value))
      ..sort(_compareEvents);
    final results = invariants
        .map((invariant) => invariant.evaluate(events))
        .toList(growable: false);
    final eventIds = events.map((event) => event.id).toList(growable: false);

    return SimulationResult(
      runId: '${scenario.id}-${seed.value}',
      seed: seed,
      scenario: scenario,
      actors: List<SimulationActor>.unmodifiable(actors),
      events: List<SimulationEvent>.unmodifiable(events),
      invariants: results,
      replay: ReplayMetadata(
        seed: seed.value,
        scenarioId: scenario.id,
        eventIds: eventIds,
      ),
    );
  }

  static int _compareEvents(SimulationEvent left, SimulationEvent right) {
    final time = left.at.compareTo(right.at);
    if (time != 0) {
      return time;
    }
    final sequence = left.sequence.compareTo(right.sequence);
    if (sequence != 0) {
      return sequence;
    }
    return left.id.compareTo(right.id);
  }
}
