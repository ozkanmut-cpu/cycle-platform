import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  const generator = CohortGenerator();

  test('canonical cohort has exact deterministic actor counts', () {
    final first = generator.canonical(20260915);
    final second = generator.canonical(20260915);
    expect(first.patients, hasLength(100));
    expect(first.partners, hasLength(50));
    expect(first.doctors, hasLength(5));
    expect(first.toNormalizedJson(), second.toNormalizedJson());
  });

  test('actor IDs are unique and links never dangle', () {
    final cohort = generator.canonical(42);
    final ids = [...cohort.patients, ...cohort.partners, ...cohort.doctors]
        .map((persona) => persona.id)
        .toSet();
    expect(ids, hasLength(155));
    final patientIds = cohort.patients.map((p) => p.id).toSet();
    expect(cohort.partnerLinks.every((l) => patientIds.contains(l.patientId)),
        isTrue);
    expect(cohort.doctorAssignments.expand((a) => a.patientIds).toSet(),
        patientIds);
  });

  test('required risk and accessibility coverage is represented', () {
    final cohort = generator.canonical(20260915);
    final coverage = cohort.coverageSummary();
    for (final key in [
      'lowHealthLiteracy',
      'accessibilityNeeds',
      'highPrivacy',
      'wearableHeavy',
      'noWearable',
      'conflictingData',
      'highSymptomBurden'
    ]) {
      expect(coverage[key] as int, greaterThan(0), reason: key);
    }
  });

  test('cohort round-trips without semantic loss', () {
    final cohort = generator.canonical(7);
    final decoded =
        jsonDecode(cohort.toNormalizedJson()) as Map<String, dynamic>;
    final restored = SimulationCohort.fromJson(decoded.cast<String, Object?>());
    expect(restored.toNormalizedJson(), cohort.toNormalizedJson());
  });

  test('unsafe partner intimacy is rejected through cohort validation', () {
    final cohort = generator.canonical(9);
    final original = cohort.partners.first;
    final unsafe = PartnerPersona(
      id: original.id,
      core: original.core,
      relationshipType: original.relationshipType,
      sharingGrants: original.sharingGrants,
      relationshipCategoryGrants: original.relationshipCategoryGrants,
      playfulEnabled: original.playfulEnabled,
      intimacyEnabled: true,
      boundarySensitivity: original.boundarySensitivity,
    );
    final changed = SimulationCohort(
      seed: cohort.seed,
      patients: cohort.patients,
      partners: [unsafe, ...cohort.partners.skip(1)],
      doctors: cohort.doctors,
      partnerLinks: cohort.partnerLinks,
      doctorAssignments: cohort.doctorAssignments,
    );
    expect(changed.validate, throwsArgumentError);
  });
}
