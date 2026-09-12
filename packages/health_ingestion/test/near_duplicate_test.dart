import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:test/test.dart';

void main() {
  List<NormalizedHealthRecord> ingest(
    HealthSourcePlatform platform,
    List<RawHealthRecord> records,
  ) {
    final pipeline = HealthIngestionPipeline(
      mappings: defaultHealthMappings,
      permissionPolicy: AllowlistedImportPermissionPolicy(
        HealthDataCategory.values.toSet(),
      ),
    );
    return pipeline.ingest(sourcePlatform: platform, records: records).records;
  }

  test('cross-source equivalent observations are flagged without data loss',
      () {
    final observedAt = DateTime.utc(2026, 9, 12, 8, 5);
    final records = [
      ...ingest(
        HealthSourcePlatform.healthConnect,
        [
          RawHealthRecord(
            sourcePlatform: HealthSourcePlatform.healthConnect,
            sourceType: 'heart_rate',
            sourceRecordId: 'hc-1',
            observedAt: observedAt,
            value: 72,
            unit: 'bpm',
          ),
        ],
      ),
      ...ingest(
        HealthSourcePlatform.healthKit,
        [
          RawHealthRecord(
            sourcePlatform: HealthSourcePlatform.healthKit,
            sourceType: 'heart_rate',
            sourceRecordId: 'hk-1',
            observedAt: observedAt.add(const Duration(seconds: 20)),
            value: 72,
            unit: 'bpm',
          ),
        ],
      ),
    ];

    final groups = const DeterministicNearDuplicateDetector().detect(records);

    expect(groups, hasLength(1));
    expect(groups.single.records, hasLength(2));
    expect(
      groups.single.recordKeys,
      containsAll([
        'healthConnect|hc-1|vital.heart_rate',
        'healthKit|hk-1|vital.heart_rate',
      ]),
    );
  });

  test('observations outside the time window are not flagged', () {
    final observedAt = DateTime.utc(2026, 9, 12, 8, 5);
    final records = ingest(
      HealthSourcePlatform.healthConnect,
      [
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'heart_rate',
          sourceRecordId: 'hr-1',
          observedAt: observedAt,
          value: 72,
          unit: 'bpm',
        ),
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'heart_rate',
          sourceRecordId: 'hr-2',
          observedAt: observedAt.add(const Duration(seconds: 31)),
          value: 72,
          unit: 'bpm',
        ),
      ],
    );

    final groups = const DeterministicNearDuplicateDetector().detect(records);

    expect(groups, isEmpty);
  });

  test('three close equivalents form one non-overlapping group', () {
    final observedAt = DateTime.utc(2026, 9, 12, 8, 5);
    final records = ingest(
      HealthSourcePlatform.healthConnect,
      [
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'heart_rate',
          sourceRecordId: 'hr-1',
          observedAt: observedAt,
          value: 72,
          unit: 'bpm',
        ),
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'heart_rate',
          sourceRecordId: 'hr-2',
          observedAt: observedAt.add(const Duration(seconds: 10)),
          value: 72,
          unit: 'bpm',
        ),
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'heart_rate',
          sourceRecordId: 'hr-3',
          observedAt: observedAt.add(const Duration(seconds: 20)),
          value: 72,
          unit: 'bpm',
        ),
      ],
    );

    const detector = DeterministicNearDuplicateDetector();
    final forward = detector.detect(records);
    final reverse = detector.detect(records.reversed);

    expect(forward, hasLength(1));
    expect(forward.single.records, hasLength(3));
    expect(forward.single.recordKeys.toSet(), hasLength(3));
    expect(reverse, hasLength(1));
    expect(reverse.single.recordKeys, forward.single.recordKeys);
  });
}
