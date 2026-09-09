import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:test/test.dart';

void main() {
  test('Observation preserves value, unit and reference range', () {
    final now = DateTime.utc(2026, 9, 9, 15);
    final observation = Observation(
      id: 'obs-ferritin-1',
      subjectId: 'patient-1',
      code: 'lab.ferritin',
      value: 24,
      unit: 'ng/mL',
      referenceRangeLow: 15,
      referenceRangeHigh: 150,
      temporal: TemporalMetadata(
        observedAt: now,
        recordedAt: now,
        knownAt: now,
      ),
      provenance: const Provenance(
        sourceKind: SourceKind.clinicalSystem,
        sourceName: 'FHIR',
      ),
      confidence: ConfidenceClass.high,
    );

    expect(observation.value, 24);
    expect(observation.unit, 'ng/mL');
    expect(observation.referenceRangeLow, 15);
    expect(observation.referenceRangeHigh, 150);
    expect(observation.temporal.knownAt, now);
  });

  test('notRecorded remains distinct from a negative observation', () {
    final now = DateTime.utc(2026, 9, 9, 15);
    final observation = Observation(
      id: 'obs-symptom-1',
      subjectId: 'patient-1',
      code: 'symptom.pelvic_pain',
      dataState: DataState.notRecorded,
      temporal: TemporalMetadata(observedAt: now, recordedAt: now),
      provenance: const Provenance(sourceKind: SourceKind.patient),
      confidence: ConfidenceClass.unknown,
    );

    expect(observation.dataState, DataState.notRecorded);
    expect(observation.dataState, isNot(DataState.no));
  });

  test('knownAt can differ from clinical observation time', () {
    final observed = DateTime.utc(2026, 8, 1, 9);
    final learned = DateTime.utc(2026, 9, 9, 15);
    final temporal = TemporalMetadata(
      observedAt: observed,
      recordedAt: learned,
      importedAt: learned,
      knownAt: learned,
    );

    expect(temporal.observedAt, observed);
    expect(temporal.knownAt, learned);
    expect(temporal.knownAt, isNot(temporal.observedAt));
  });
}
