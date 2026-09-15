import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  const cohortGenerator = CohortGenerator();
  const worldGenerator = SyntheticHealthWorldGenerator();

  test('same seed produces identical synthetic health world', () {
    final cohort = cohortGenerator.canonical(20260915);
    final first = worldGenerator.generate(cohort: cohort, seed: 20260915);
    final second = worldGenerator.generate(cohort: cohort, seed: 20260915);
    expect(first.toNormalizedJson(), second.toNormalizedJson());
  });

  test('world covers all patients and uncertainty states', () {
    final cohort = cohortGenerator.canonical(20260915);
    final world = worldGenerator.generate(cohort: cohort, seed: 77);
    final coverage = world.coverageSummary();
    expect(world.timelines, hasLength(100));
    expect(coverage['patients'], 100);
    expect(coverage['observations'] as int, greaterThan(100));
    expect(coverage['missing'] as int, greaterThan(0));
    expect(coverage['estimated'] as int, greaterThan(0));
    expect(coverage['conflicting'] as int, greaterThan(0));
    expect(coverage['manual'] as int, greaterThan(0));
    expect(coverage['wearable'] as int, greaterThan(0));
    expect(coverage['clinical'] as int, greaterThan(0));
  });

  test('missing is never encoded as zero', () {
    final cohort = cohortGenerator.canonical(42);
    final world = worldGenerator.generate(cohort: cohort, seed: 42);
    final missing = world.timelines
        .expand((timeline) => timeline.observations)
        .where((item) => item.state == SyntheticDataState.missing);
    expect(missing, isNotEmpty);
    expect(missing.every((item) => item.value == null), isTrue);
  });

  test('world round-trips without semantic loss', () {
    final cohort = cohortGenerator.canonical(7);
    final world = worldGenerator.generate(cohort: cohort, seed: 7, days: 14);
    final decoded = jsonDecode(world.toNormalizedJson()) as Map<String, dynamic>;
    final restored =
        SyntheticHealthWorld.fromJson(decoded.cast<String, Object?>());
    restored.validate(cohort: cohort);
    expect(restored.toNormalizedJson(), world.toNormalizedJson());
  });

  test('malformed uncertainty semantics are rejected', () {
    final invalidMissing = SyntheticHealthObservation(
      id: 'bad-missing',
      patientId: 'patient-1',
      kind: HealthSignalKind.symptomSeverity,
      observedAt: DateTime.utc(2026, 1, 1),
      state: SyntheticDataState.missing,
      source: SyntheticSourceKind.manual,
      value: 0,
    );
    expect(invalidMissing.validate, throwsArgumentError);

    final invalidConflict = SyntheticHealthObservation(
      id: 'bad-conflict',
      patientId: 'patient-1',
      kind: HealthSignalKind.weight,
      observedAt: DateTime.utc(2026, 1, 1),
      state: SyntheticDataState.conflicting,
      source: SyntheticSourceKind.clinical,
      value: 60,
      conflictingValue: 60,
    );
    expect(invalidConflict.validate, throwsArgumentError);
  });
}
