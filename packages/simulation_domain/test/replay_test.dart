import 'dart:io';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('failure bundle replay reproduces target invariant exactly', () {
    final bundle = _missingBundle();
    final outcome = const ReplayEngine().replay(
      bundle: bundle,
      invariant: const MissingIsNotZeroInvariant(),
    );

    expect(outcome.matches(bundle), isTrue);
    expect(outcome.target.id, 'missing-is-not-zero');
    expect(outcome.target.severity, InvariantSeverity.s4);
  });

  test('replay identity is stable for identical bundle content', () {
    final first = _missingBundle();
    final second = _missingBundle();

    expect(first.replay.toJson(), second.replay.toJson());
  });

  test('failure bundle JSON round-trips without semantic loss', () {
    final source =
        File('test/fixtures/missing_failure.json').readAsStringSync();
    final decoded = FailureBundle.decode(source);
    final roundTripped = FailureBundle.decode(decoded.toNormalizedJson());

    expect(roundTripped.toNormalizedJson(), decoded.toNormalizedJson());
    expect(
      const ReplayEngine()
          .replay(
            bundle: roundTripped,
            invariant: const MissingIsNotZeroInvariant(),
          )
          .matches(roundTripped),
      isTrue,
    );
  });

  test('minimizer removes irrelevant events and preserves target failure', () {
    final bundle = _missingBundle();
    final minimized = const ScenarioMinimizer().minimize(
      bundle: bundle,
      invariant: const MissingIsNotZeroInvariant(),
    );

    expect(minimized.events.map((event) => event.id), <String>['bad-missing']);
    final replay = const ReplayEngine().replay(
      bundle: minimized,
      invariant: const MissingIsNotZeroInvariant(),
    );
    expect(replay.matches(minimized), isTrue);
  });

  test('minimizer refuses a bundle whose target failure is not reproducible',
      () {
    final bundle = FailureBundle(
      schemaVersion: 1,
      targetInvariantId: 'missing-is-not-zero',
      seed: 1,
      scenario: const SimulationScenario(id: 'clean', name: 'Clean'),
      actors: const <SimulationActor>[
        SimulationActor(id: 'P-001', kind: SimulationActorKind.patient),
      ],
      events: <SimulationEvent>[
        SimulationEvent(
          id: 'ok',
          type: 'dataMissing',
          at: DateTime.utc(2026, 1, 1),
          sequence: 0,
          actorId: 'P-001',
        ),
      ],
      expectedSeverity: InvariantSeverity.s4,
      expectedEvidence: const <String, Object?>{
        'violatingEventIds': <String>['bad-missing'],
      },
    );

    expect(
      () => const ScenarioMinimizer().minimize(
        bundle: bundle,
        invariant: const MissingIsNotZeroInvariant(),
      ),
      throwsStateError,
    );
  });
}

FailureBundle _missingBundle() => FailureBundle(
      schemaVersion: 1,
      targetInvariantId: 'missing-is-not-zero',
      seed: 20260914,
      scenario: const SimulationScenario(
        id: 'replay-missing',
        name: 'Replay missing failure',
      ),
      actors: const <SimulationActor>[
        SimulationActor(id: 'P-001', kind: SimulationActorKind.patient),
      ],
      events: <SimulationEvent>[
        SimulationEvent(
          id: 'irrelevant-1',
          type: 'manualLog',
          at: DateTime.utc(2026, 1, 1),
          sequence: 0,
          actorId: 'P-001',
        ),
        SimulationEvent(
          id: 'bad-missing',
          type: 'dataMissing',
          at: DateTime.utc(2026, 1, 2),
          sequence: 1,
          actorId: 'P-001',
          payload: const <String, Object?>{'value': 0},
        ),
        SimulationEvent(
          id: 'irrelevant-2',
          type: 'manualLog',
          at: DateTime.utc(2026, 1, 3),
          sequence: 2,
          actorId: 'P-001',
        ),
      ],
      expectedSeverity: InvariantSeverity.s4,
      expectedEvidence: const <String, Object?>{
        'violatingEventIds': <String>['bad-missing'],
      },
    );
