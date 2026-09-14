import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  group('determinism', () {
    test('same seed and scenario produce byte-stable normalized results', () {
      final first = _runFoundation(20260914);
      final second = _runFoundation(20260914);

      expect(first.toNormalizedJson(), second.toNormalizedJson());
      expect(first.replay.eventIds, second.replay.eventIds);
    });

    test('different seed changes generated event payload', () {
      final first = _runFoundation(20260914);
      final second = _runFoundation(20260915);

      expect(first.toNormalizedJson(), isNot(second.toNormalizedJson()));
    });
  });

  test('simulation clock never depends on wall clock', () {
    final clock = SimulationClock(DateTime.utc(2026, 1, 1));
    clock.advance(const Duration(days: 90));

    expect(clock.now, DateTime.utc(2026, 4, 1));
    expect(
      () => clock.moveTo(DateTime.utc(2026, 3, 31)),
      throwsStateError,
    );
  });

  test('events are totally ordered by time, sequence and id', () {
    final result = const SimulationRunner().run(
      seed: const SimulationSeed(1),
      scenario: const SimulationScenario(id: 'ordering', name: 'Ordering'),
      actors: const <SimulationActor>[
        SimulationActor(id: 'P-001', kind: SimulationActorKind.patient),
      ],
      eventFactory: (_) => <SimulationEvent>[
        SimulationEvent(
          id: 'b',
          type: 'manualLog',
          at: DateTime.utc(2026, 1, 2),
          sequence: 2,
          actorId: 'P-001',
        ),
        SimulationEvent(
          id: 'a',
          type: 'manualLog',
          at: DateTime.utc(2026, 1, 2),
          sequence: 1,
          actorId: 'P-001',
        ),
        SimulationEvent(
          id: 'c',
          type: 'manualLog',
          at: DateTime.utc(2026, 1, 1),
          sequence: 3,
          actorId: 'P-001',
        ),
      ],
    );

    expect(result.events.map((event) => event.id), <String>['c', 'a', 'b']);
  });

  test('missing observation represented as zero is an S4 failure', () {
    final result = const SimulationRunner().run(
      seed: const SimulationSeed(1),
      scenario: const SimulationScenario(id: 'missing', name: 'Missing'),
      actors: const <SimulationActor>[
        SimulationActor(id: 'P-001', kind: SimulationActorKind.patient),
      ],
      eventFactory: (_) => <SimulationEvent>[
        SimulationEvent(
          id: 'missing-1',
          type: 'dataMissing',
          at: DateTime.utc(2026, 1, 1),
          sequence: 0,
          actorId: 'P-001',
          payload: <String, Object?>{'value': 0},
        ),
      ],
      invariants: const <SimulationInvariant>[MissingIsNotZeroInvariant()],
    );

    expect(result.passed, isFalse);
    expect(result.invariants.single.severity, InvariantSeverity.s4);
    expect(
      result.invariants.single.evidence['violatingEventIds'],
      <String>['missing-1'],
    );
  });

  test('permission access at revocation boundary is an S4 failure', () {
    final at = DateTime.utc(2026, 1, 3);
    final result = const SimulationRunner().run(
      seed: const SimulationSeed(1),
      scenario: const SimulationScenario(
        id: 'revocation',
        name: 'Revocation boundary',
      ),
      actors: const <SimulationActor>[
        SimulationActor(id: 'PARTNER-001', kind: SimulationActorKind.partner),
      ],
      eventFactory: (_) => <SimulationEvent>[
        SimulationEvent(
          id: 'revoke',
          type: 'permissionRevoked',
          at: at,
          sequence: 0,
          actorId: 'PARTNER-001',
          payload: const <String, Object?>{'category': 'cycle'},
        ),
        SimulationEvent(
          id: 'read',
          type: 'permissionRead',
          at: at,
          sequence: 1,
          actorId: 'PARTNER-001',
          payload: const <String, Object?>{'category': 'cycle'},
        ),
      ],
      invariants: const <SimulationInvariant>[
        PermissionRevocationInvariant(),
      ],
    );

    expect(result.passed, isFalse);
    expect(result.invariants.single.severity, InvariantSeverity.s4);
  });
}

SimulationResult _runFoundation(int seed) {
  final random = DeterministicRandom(seed);
  return const SimulationRunner().run(
    seed: SimulationSeed(seed),
    scenario: const SimulationScenario(
      id: 'foundation-smoke',
      name: 'Foundation smoke',
    ),
    actors: const <SimulationActor>[
      SimulationActor(id: 'P-001', kind: SimulationActorKind.patient),
    ],
    eventFactory: (_) => <SimulationEvent>[
      SimulationEvent(
        id: 'event-1',
        type: 'manualLog',
        at: DateTime.utc(2026, 1, 1),
        sequence: 0,
        actorId: 'P-001',
        payload: <String, Object?>{'intensity': random.nextInt(10)},
      ),
      SimulationEvent(
        id: 'event-2',
        type: 'dataMissing',
        at: DateTime.utc(2026, 1, 2),
        sequence: 1,
        actorId: 'P-001',
      ),
    ],
    invariants: const <SimulationInvariant>[MissingIsNotZeroInvariant()],
  );
}
