import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:test/test.dart';

void main() {
  test('data states keep unknown distinct from no', () {
    expect(DataState.unknown, isNot(DataState.no));
    expect(DataState.notRecorded, isNot(DataState.no));
  });

  test('HealthEvent preserves provenance and clinical-source status', () {
    final now = DateTime.utc(2026, 9, 9, 14);
    final event = HealthEvent(
      id: 'evt-1',
      subjectId: 'patient-1',
      eventType: 'observation.hemoglobin',
      value: 12.7,
      unit: 'g/dL',
      temporal: TemporalMetadata(observedAt: now, recordedAt: now),
      provenance: const Provenance(
        sourceKind: SourceKind.clinicalSystem,
        sourceName: 'FHIR',
      ),
      verificationStatus: VerificationStatus.clinicalSource,
      confidence: ConfidenceClass.high,
      privacyClass: 'medical',
      schemaVersion: 1,
    );

    expect(event.isClinicalSource, isTrue);
    expect(event.provenance.sourceName, 'FHIR');
    expect(event.value, 12.7);
  });

  test('Episode is open until it is ended', () {
    final episode = Episode(
      id: 'pregnancy-1',
      subjectId: 'patient-1',
      episodeType: 'pregnancy',
      startedAt: DateTime.utc(2026, 1, 1),
      schemaVersion: 1,
    );

    expect(episode.isOpen, isTrue);
  });
}
