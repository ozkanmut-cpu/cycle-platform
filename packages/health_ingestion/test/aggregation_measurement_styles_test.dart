import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:test/test.dart';

void main() {
  List<NormalizedHealthRecord> ingest(List<RawHealthRecord> records) {
    final pipeline = HealthIngestionPipeline(
      mappings: defaultHealthMappings,
      permissionPolicy: AllowlistedImportPermissionPolicy(
        HealthDataCategory.values.toSet(),
      ),
    );
    return pipeline
        .ingest(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          records: records,
        )
        .records;
  }

  DeterministicHealthSensorAggregator defaultAggregator() =>
      DeterministicHealthSensorAggregator(
        policyResolver: MapAggregationPolicyResolver(
          defaultSensorAggregationPolicies,
        ),
      );

  test('continuous heart-rate samples use hourly mean policy', () {
    final records = ingest([
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'heart_rate',
        sourceRecordId: 'continuous-hr-1',
        observedAt: DateTime.utc(2026, 9, 12, 8, 5),
        value: 60,
        unit: 'bpm',
      ),
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'heart_rate',
        sourceRecordId: 'continuous-hr-2',
        observedAt: DateTime.utc(2026, 9, 12, 8, 35),
        value: 80,
        unit: 'bpm',
      ),
    ]);

    final result = defaultAggregator()
        .aggregate(
          records: records,
          rangeStart: DateTime.utc(2026, 9, 12, 8),
          rangeEnd: DateTime.utc(2026, 9, 12, 9),
        )
        .single;

    expect(result.canonicalCode, 'vital.heart_rate');
    expect(result.policyId, 'heart-rate-hourly-mean');
    expect(result.value, 70.0);
    expect(result.unit, 'bpm');
    expect(result.contributingRecords, hasLength(2));
    expect(result.missingness, AggregationMissingness.observed);
  });

  test('episodic menstruation observations use latest daily value', () {
    final records = ingest([
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'menstruation_flow',
        sourceRecordId: 'flow-1',
        observedAt: DateTime.utc(2026, 9, 12, 7),
        value: 'light',
      ),
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'menstruation_flow',
        sourceRecordId: 'flow-2',
        observedAt: DateTime.utc(2026, 9, 12, 19),
        value: 'heavy',
      ),
    ]);

    final result = defaultAggregator()
        .aggregate(
          records: records,
          rangeStart: DateTime.utc(2026, 9, 12),
          rangeEnd: DateTime.utc(2026, 9, 13),
        )
        .single;

    expect(result.canonicalCode, 'reproductive.menstruation.flow');
    expect(result.policyId, 'menstruation-flow-daily-latest');
    expect(result.value, 'heavy');
    expect(result.unit, isNull);
    expect(result.contributingRecords, hasLength(2));
    expect(result.missingness, AggregationMissingness.observed);
  });

  test('interval-style sleep sessions sum daily duration', () {
    final records = ingest([
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'sleep_session',
        sourceRecordId: 'sleep-1',
        observedAt: DateTime.utc(2026, 9, 12, 1),
        value: const Duration(hours: 4),
      ),
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'sleep_session',
        sourceRecordId: 'sleep-2',
        observedAt: DateTime.utc(2026, 9, 12, 6),
        value: const Duration(hours: 3),
      ),
    ]);

    final result = defaultAggregator()
        .aggregate(
          records: records,
          rangeStart: DateTime.utc(2026, 9, 12),
          rangeEnd: DateTime.utc(2026, 9, 13),
        )
        .single;

    expect(result.canonicalCode, 'sleep.session');
    expect(result.policyId, 'sleep-daily-duration');
    expect(result.value, const Duration(hours: 7));
    expect(result.unit, isNull);
    expect(result.contributingRecords, hasLength(2));
    expect(result.missingness, AggregationMissingness.observed);
  });
}
