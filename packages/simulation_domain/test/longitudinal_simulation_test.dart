import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  group('LongitudinalSimulationGenerator', () {
    test('same inputs and seed produce identical five-year trajectories', () {
      const seed = 20260915;
      final cohort = const CohortGenerator().canonical(seed);
      final world = const SyntheticHealthWorldGenerator().generate(
        cohort: cohort,
        seed: seed,
      );
      final generator = const LongitudinalSimulationGenerator();

      final first = generator.generate(
        cohort: cohort,
        healthWorld: world,
        seed: seed,
        years: 5,
      );
      final second = generator.generate(
        cohort: cohort,
        healthWorld: world,
        seed: seed,
        years: 5,
      );

      expect(first.toNormalizedJson(), second.toNormalizedJson());
      expect(first.trajectories, hasLength(100));
      expect(first.years, 5);
    });

    test('supports deterministic one, three and five year horizons', () {
      const seed = 42;
      final cohort = const CohortGenerator().canonical(seed);
      final world = const SyntheticHealthWorldGenerator().generate(
        cohort: cohort,
        seed: seed,
      );
      const generator = LongitudinalSimulationGenerator();

      for (final years in [1, 3, 5]) {
        final simulation = generator.generate(
          cohort: cohort,
          healthWorld: world,
          seed: seed,
          years: years,
        );
        simulation.validate(cohort: cohort);
        expect(simulation.years, years);
        expect(simulation.trajectories, hasLength(cohort.patients.length));
        expect(
          simulation.trajectories.every((item) => item.epochs.isNotEmpty),
          isTrue,
        );
      }
    });

    test(
      'coverage exercises temporal patterns and uncertainty without collapse',
      () {
        const seed = 20260915;
        final cohort = const CohortGenerator().canonical(seed);
        final world = const SyntheticHealthWorldGenerator().generate(
          cohort: cohort,
          seed: seed,
        );
        final simulation = const LongitudinalSimulationGenerator().generate(
          cohort: cohort,
          healthWorld: world,
          seed: seed,
          years: 5,
        );
        final coverage = simulation.coverageSummary();

        for (final pattern in LongitudinalPattern.values) {
          expect(coverage[pattern.name], greaterThan(0), reason: pattern.name);
        }
        expect(coverage['missing'], greaterThan(0));
        expect(coverage['estimated'], greaterThan(0));
        expect(coverage['conflicting'], greaterThan(0));
        expect(coverage['sourceTransitions'], greaterThan(0));

        for (final epoch
            in simulation.trajectories.expand((item) => item.epochs)) {
          if (epoch.state == SyntheticDataState.missing) {
            expect(epoch.value, isNull);
            expect(epoch.conflictingValue, isNull);
          }
          if (epoch.state == SyntheticDataState.conflicting) {
            expect(epoch.value, isNotNull);
            expect(epoch.conflictingValue, isNotNull);
            expect(epoch.conflictingValue, isNot(epoch.value));
          }
        }
      },
    );

    test('round trip preserves longitudinal semantics', () {
      const seed = 9;
      final cohort = const CohortGenerator().canonical(seed);
      final world = const SyntheticHealthWorldGenerator().generate(
        cohort: cohort,
        seed: seed,
      );
      final original = const LongitudinalSimulationGenerator().generate(
        cohort: cohort,
        healthWorld: world,
        seed: seed,
        years: 3,
      );
      final restored = LongitudinalSimulation.fromJson(original.toJson());

      restored.validate(cohort: cohort);
      expect(restored.toNormalizedJson(), original.toNormalizedJson());
    });

    test('malformed overlapping epochs fail safely', () {
      final first = LongitudinalEpoch(
        id: 'p-0001-e-0001',
        patientId: 'p-0001',
        startsAt: DateTime.utc(2026, 1, 1),
        endsAt: DateTime.utc(2026, 4, 1),
        pattern: LongitudinalPattern.stable,
        state: SyntheticDataState.known,
        source: SyntheticSourceKind.manual,
        value: 3,
      );
      final overlapping = LongitudinalEpoch(
        id: 'p-0001-e-0002',
        patientId: 'p-0001',
        startsAt: DateTime.utc(2026, 3, 1),
        endsAt: DateTime.utc(2026, 6, 1),
        pattern: LongitudinalPattern.drift,
        state: SyntheticDataState.known,
        source: SyntheticSourceKind.manual,
        value: 4,
      );
      final trajectory = LongitudinalPatientTrajectory(
        patientId: 'p-0001',
        epochs: [first, overlapping],
      );

      expect(trajectory.validate, throwsArgumentError);
    });
  });
}
