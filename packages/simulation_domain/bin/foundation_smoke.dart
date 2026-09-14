import 'dart:io';

import 'package:cycle_simulation_domain/simulation_domain.dart';

void main(List<String> args) {
  final seed = _seedFromArgs(args);
  final random = DeterministicRandom(seed);
  final result = const SimulationRunner().run(
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

  stdout.writeln(result.toNormalizedJson());
  if (!result.passed) {
    exitCode = 1;
  }
}

int _seedFromArgs(List<String> args) {
  const fallback = 20260914;
  for (final arg in args) {
    if (arg.startsWith('--seed=')) {
      return int.tryParse(arg.substring('--seed='.length)) ?? fallback;
    }
  }
  return fallback;
}
