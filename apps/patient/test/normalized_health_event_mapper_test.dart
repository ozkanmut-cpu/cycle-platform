import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:cycle_patient/health/normalized_health_event_mapper.dart';
import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = NormalizedHealthEventMapper();

  test('uses a deterministic source-backed event id', () {
    expect(
      mapper.eventIdFor(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceRecordId: 'record-42',
      ),
      'import:healthConnect:record-42',
    );
  });

  test('preserves provenance and normalized measurement', () {
    final importedAt = DateTime.utc(2026, 9, 9, 19, 30);
    final observedAt = DateTime.utc(2026, 9, 9, 19, 20);
    final record = NormalizedHealthRecord(
      source: RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthKit,
        sourceType: 'weight',
        sourceRecordId: 'weight-1',
        observedAt: observedAt,
        value: 70,
        unit: 'kg',
        sourceName: 'Apple Health',
      ),
      mapping: const HealthTypeMapping(
        sourceType: 'weight',
        canonicalCode: 'body.weight',
        category: HealthDataCategory.body,
        canonicalUnit: 'kg',
      ),
      normalizedValue: 70,
      normalizedUnit: 'kg',
      provenance: const Provenance(
        sourceKind: SourceKind.healthKit,
        sourceName: 'Apple Health',
        sourceRecordId: 'weight-1',
      ),
    );

    final event = mapper.toHealthEvent(
      subjectId: 'local-owner',
      record: record,
      importedAt: importedAt,
    );

    expect(event.id, 'import:healthKit:weight-1');
    expect(event.eventType, 'body.weight');
    expect(event.value, 70);
    expect(event.unit, 'kg');
    expect(event.provenance.sourceKind, SourceKind.healthKit);
    expect(event.verificationStatus, VerificationStatus.deviceMeasured);
    expect(event.temporal.observedAt, observedAt);
    expect(event.temporal.importedAt, importedAt);
    expect(event.privacyClass, 'health');
  });
}
