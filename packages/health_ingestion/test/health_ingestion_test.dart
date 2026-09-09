import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes units and preserves Health Connect provenance', () {
    final pipeline = HealthIngestionPipeline(
      mappings: defaultHealthMappings,
      permissionPolicy: AllowlistedImportPermissionPolicy({
        HealthDataCategory.body,
      }),
    );

    final result = pipeline.ingest(
      sourcePlatform: HealthSourcePlatform.healthConnect,
      records: [
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'weight',
          sourceRecordId: 'hc-weight-1',
          observedAt: DateTime.utc(2026, 9, 9, 8),
          value: 150,
          unit: 'lb',
          sourceName: 'Health Connect',
          deviceName: 'Example Scale',
        ),
      ],
    );

    expect(result.records, hasLength(1));
    expect(result.records.single.normalizedUnit, 'kg');
    expect(result.records.single.normalizedValue, closeTo(68.0388555, 0.0001));
    expect(
      result.records.single.provenance.sourceKind,
      SourceKind.healthConnect,
    );
    expect(result.records.single.provenance.sourceRecordId, 'hc-weight-1');
  });

  test('permission policy blocks categories independently', () {
    final pipeline = HealthIngestionPipeline(
      mappings: defaultHealthMappings,
      permissionPolicy: AllowlistedImportPermissionPolicy({
        HealthDataCategory.vitals,
      }),
    );

    final result = pipeline.ingest(
      sourcePlatform: HealthSourcePlatform.healthKit,
      records: [
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthKit,
          sourceType: 'heart_rate',
          sourceRecordId: 'hk-hr-1',
          observedAt: DateTime.utc(2026, 9, 9, 8),
          value: 72,
          unit: 'bpm',
        ),
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthKit,
          sourceType: 'sleep_session',
          sourceRecordId: 'hk-sleep-1',
          observedAt: DateTime.utc(2026, 9, 9, 1),
          value: 7.5,
          unit: 'h',
        ),
      ],
    );

    expect(result.records, hasLength(1));
    expect(result.records.single.mapping.canonicalCode, 'vital.heart_rate');
    expect(result.history.skippedPermission, 1);
  });

  test('deduplication and unmapped records are reflected in history', () {
    final pipeline = HealthIngestionPipeline(
      mappings: defaultHealthMappings,
      permissionPolicy: AllowlistedImportPermissionPolicy(
        HealthDataCategory.values.toSet(),
      ),
    );

    final records = [
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'oxygen_saturation',
        sourceRecordId: 'spo2-1',
        observedAt: DateTime.utc(2026, 9, 9, 9),
        value: 97,
        unit: '%',
      ),
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'oxygen_saturation',
        sourceRecordId: 'spo2-1',
        observedAt: DateTime.utc(2026, 9, 9, 9),
        value: 97,
        unit: '%',
      ),
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'unsupported.future.type',
        sourceRecordId: 'future-1',
        observedAt: DateTime.utc(2026, 9, 9, 9),
        value: 1,
      ),
    ];

    final result = pipeline.ingest(
      sourcePlatform: HealthSourcePlatform.healthConnect,
      records: records,
    );

    expect(result.records, hasLength(1));
    expect(result.history.imported, 1);
    expect(result.history.skippedDuplicate, 1);
    expect(result.history.unmapped, 1);
  });
}
