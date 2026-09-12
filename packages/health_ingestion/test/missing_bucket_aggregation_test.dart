import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:test/test.dart';

void main() {
  test('emits explicit missing buckets without converting them to zero', () {
    const policy = AggregationPolicy(
      policyId: 'heart-rate-hourly-mean',
      version: 1,
      canonicalCode: 'vital.heart_rate',
      method: AggregationMethod.mean,
      bucketSize: Duration(hours: 1),
    );
    final pipeline = HealthIngestionPipeline(
      mappings: defaultHealthMappings,
      permissionPolicy: AllowlistedImportPermissionPolicy(
        HealthDataCategory.values.toSet(),
      ),
    );
    final records = pipeline.ingest(
      sourcePlatform: HealthSourcePlatform.healthConnect,
      records: [
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'heart_rate',
          sourceRecordId: 'hr-1',
          observedAt: DateTime.utc(2026, 9, 12, 8, 15),
          value: 72,
          unit: 'bpm',
        ),
      ],
    ).records;
    final baseAggregator = DeterministicHealthSensorAggregator(
      policyResolver: MapAggregationPolicyResolver(const [policy]),
    );

    final result = const DeterministicMissingBucketAggregator().aggregate(
      aggregator: baseAggregator,
      records: records,
      policies: const [policy],
      rangeStart: DateTime.utc(2026, 9, 12, 8),
      rangeEnd: DateTime.utc(2026, 9, 12, 11),
    );

    expect(result, hasLength(3));
    expect(result[0].value, 72.0);
    expect(result[0].missingness, AggregationMissingness.observed);

    for (final missing in result.skip(1)) {
      expect(missing.value, isNull);
      expect(missing.unit, isNull);
      expect(missing.contributingRecords, isEmpty);
      expect(missing.missingness, AggregationMissingness.missing);
    }
  });

  test('partial final bucket ends at requested range end', () {
    const policy = AggregationPolicy(
      policyId: 'heart-rate-hourly-mean',
      version: 1,
      canonicalCode: 'vital.heart_rate',
      method: AggregationMethod.mean,
      bucketSize: Duration(hours: 1),
    );
    final baseAggregator = DeterministicHealthSensorAggregator(
      policyResolver: MapAggregationPolicyResolver(const [policy]),
    );

    final result = const DeterministicMissingBucketAggregator().aggregate(
      aggregator: baseAggregator,
      records: const <NormalizedHealthRecord>[],
      policies: const [policy],
      rangeStart: DateTime.utc(2026, 9, 12, 8),
      rangeEnd: DateTime.utc(2026, 9, 12, 9, 30),
    );

    expect(result, hasLength(2));
    expect(result.last.bucketStart, DateTime.utc(2026, 9, 12, 9));
    expect(result.last.bucketEnd, DateTime.utc(2026, 9, 12, 9, 30));
    expect(result.last.missingness, AggregationMissingness.missing);
  });
}
