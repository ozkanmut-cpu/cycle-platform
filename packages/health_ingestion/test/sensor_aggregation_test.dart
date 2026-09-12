import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:test/test.dart';

void main() {
  List<NormalizedHealthRecord> ingest(
    List<RawHealthRecord> records, {
    HealthSourcePlatform platform = HealthSourcePlatform.healthConnect,
  }) {
    final pipeline = HealthIngestionPipeline(
      mappings: defaultHealthMappings,
      permissionPolicy: AllowlistedImportPermissionPolicy(
        HealthDataCategory.values.toSet(),
      ),
    );
    return pipeline
        .ingest(
          sourcePlatform: platform,
          records: records,
        )
        .records;
  }

  test('aggregation is deterministic regardless of input order', () {
    final records = ingest([
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'heart_rate',
        sourceRecordId: 'hr-2',
        observedAt: DateTime.utc(2026, 9, 12, 8, 10),
        value: 80,
        unit: 'bpm',
      ),
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'heart_rate',
        sourceRecordId: 'hr-1',
        observedAt: DateTime.utc(2026, 9, 12, 8, 5),
        value: 60,
        unit: 'bpm',
      ),
    ]);
    final aggregator = DeterministicHealthSensorAggregator(
      policyResolver: MapAggregationPolicyResolver([
        const AggregationPolicy(
          policyId: 'heart-rate-hourly-mean',
          version: 1,
          canonicalCode: 'vital.heart_rate',
          method: AggregationMethod.mean,
          bucketSize: Duration(hours: 1),
        ),
      ]),
    );

    final forward = aggregator.aggregate(
      records: records,
      rangeStart: DateTime.utc(2026, 9, 12, 8),
      rangeEnd: DateTime.utc(2026, 9, 12, 9),
    );
    final reverse = aggregator.aggregate(
      records: records.reversed,
      rangeStart: DateTime.utc(2026, 9, 12, 8),
      rangeEnd: DateTime.utc(2026, 9, 12, 9),
    );

    expect(forward.single.value, 70.0);
    expect(reverse.single.value, 70.0);
    expect(
      forward.single.contributingRecordKeys,
      reverse.single.contributingRecordKeys,
    );
  });

  test('unit mismatch is exposed as a conflict and suppresses value', () {
    final records = ingest([
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'heart_rate',
        sourceRecordId: 'hr-bpm',
        observedAt: DateTime.utc(2026, 9, 12, 8, 5),
        value: 70,
        unit: 'bpm',
      ),
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'heart_rate',
        sourceRecordId: 'hr-other-unit',
        observedAt: DateTime.utc(2026, 9, 12, 8, 10),
        value: 72,
        unit: 'beats/min',
      ),
    ]);
    final aggregator = DeterministicHealthSensorAggregator(
      policyResolver: MapAggregationPolicyResolver([
        const AggregationPolicy(
          policyId: 'heart-rate-hourly-mean',
          version: 1,
          canonicalCode: 'vital.heart_rate',
          method: AggregationMethod.mean,
          bucketSize: Duration(hours: 1),
        ),
      ]),
    );

    final result = aggregator
        .aggregate(
          records: records,
          rangeStart: DateTime.utc(2026, 9, 12, 8),
          rangeEnd: DateTime.utc(2026, 9, 12, 9),
        )
        .single;

    expect(result.value, isNull);
    expect(result.unit, isNull);
    expect(result.missingness, AggregationMissingness.partiallyMissing);
    expect(result.conflicts.single.reason, 'unit_mismatch');
  });

  test('numeric disagreement beyond tolerance is preserved as conflict', () {
    final records = ingest([
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'oxygen_saturation',
        sourceRecordId: 'spo2-1',
        observedAt: DateTime.utc(2026, 9, 12, 8, 5),
        value: 98,
        unit: '%',
      ),
      RawHealthRecord(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceType: 'oxygen_saturation',
        sourceRecordId: 'spo2-2',
        observedAt: DateTime.utc(2026, 9, 12, 8, 6),
        value: 91,
        unit: '%',
      ),
    ]);
    final aggregator = DeterministicHealthSensorAggregator(
      policyResolver: MapAggregationPolicyResolver([
        const AggregationPolicy(
          policyId: 'spo2-hourly-mean',
          version: 1,
          canonicalCode: 'vital.oxygen_saturation',
          method: AggregationMethod.mean,
          bucketSize: Duration(hours: 1),
          conflictTolerance: 3,
        ),
      ]),
    );

    final result = aggregator
        .aggregate(
          records: records,
          rangeStart: DateTime.utc(2026, 9, 12, 8),
          rangeEnd: DateTime.utc(2026, 9, 12, 9),
        )
        .single;

    expect(result.value, 94.5);
    expect(result.hasConflict, isTrue);
    expect(result.conflicts.single.reason, 'value_disagreement');
    expect(result.conflicts.single.details['spread'], 7.0);
    expect(result.conflicts.single.details['tolerance'], 3);
  });

  test('cross-source equivalent observations retain both provenances', () {
    final observedAt = DateTime.utc(2026, 9, 12, 8, 5);
    final healthConnect = ingest(
      [
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'heart_rate',
          sourceRecordId: 'hc-hr-1',
          observedAt: observedAt,
          value: 72,
          unit: 'bpm',
          sourceName: 'Health Connect source',
        ),
      ],
      platform: HealthSourcePlatform.healthConnect,
    );
    final healthKit = ingest(
      [
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthKit,
          sourceType: 'heart_rate',
          sourceRecordId: 'hk-hr-1',
          observedAt: observedAt.add(const Duration(seconds: 20)),
          value: 72,
          unit: 'bpm',
          sourceName: 'HealthKit source',
        ),
      ],
      platform: HealthSourcePlatform.healthKit,
    );
    final aggregator = DeterministicHealthSensorAggregator(
      policyResolver: MapAggregationPolicyResolver([
        const AggregationPolicy(
          policyId: 'heart-rate-hourly-mean',
          version: 1,
          canonicalCode: 'vital.heart_rate',
          method: AggregationMethod.mean,
          bucketSize: Duration(hours: 1),
        ),
      ]),
    );

    final result = aggregator.aggregate(
      records: [...healthConnect, ...healthKit],
      rangeStart: DateTime.utc(2026, 9, 12, 8),
      rangeEnd: DateTime.utc(2026, 9, 12, 9),
    ).single;

    expect(result.value, 72.0);
    expect(result.contributingRecords, hasLength(2));
    expect(
      result.contributingRecordKeys,
      containsAll(<String>[
        'healthConnect|hc-hr-1|vital.heart_rate',
        'healthKit|hk-hr-1|vital.heart_rate',
      ]),
    );
  });

  test('missing unit marks aggregate partially missing without dropping value',
      () {
    const mapping = HealthTypeMapping(
      sourceType: 'heart_rate_untyped',
      canonicalCode: 'vital.heart_rate',
      category: HealthDataCategory.vitals,
    );
    final pipeline = HealthIngestionPipeline(
      mappings: const [mapping],
      permissionPolicy: AllowlistedImportPermissionPolicy(
        HealthDataCategory.values.toSet(),
      ),
    );
    final records = pipeline.ingest(
      sourcePlatform: HealthSourcePlatform.healthConnect,
      records: [
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'heart_rate_untyped',
          sourceRecordId: 'hr-with-unit',
          observedAt: DateTime.utc(2026, 9, 12, 8, 5),
          value: 70,
          unit: 'bpm',
        ),
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'heart_rate_untyped',
          sourceRecordId: 'hr-without-unit',
          observedAt: DateTime.utc(2026, 9, 12, 8, 10),
          value: 72,
        ),
      ],
    ).records;
    final aggregator = DeterministicHealthSensorAggregator(
      policyResolver: MapAggregationPolicyResolver([
        const AggregationPolicy(
          policyId: 'heart-rate-hourly-mean',
          version: 1,
          canonicalCode: 'vital.heart_rate',
          method: AggregationMethod.mean,
          bucketSize: Duration(hours: 1),
        ),
      ]),
    );

    final result = aggregator
        .aggregate(
          records: records,
          rangeStart: DateTime.utc(2026, 9, 12, 8),
          rangeEnd: DateTime.utc(2026, 9, 12, 9),
        )
        .single;

    expect(result.value, 71.0);
    expect(result.unit, 'bpm');
    expect(result.missingness, AggregationMissingness.partiallyMissing);
    expect(result.conflicts, isEmpty);
  });

  test('unitless count aggregate remains observed', () {
    const mapping = HealthTypeMapping(
      sourceType: 'unitless_event',
      canonicalCode: 'wellness.unitless_event',
      category: HealthDataCategory.wellness,
    );
    final pipeline = HealthIngestionPipeline(
      mappings: const [mapping],
      permissionPolicy: AllowlistedImportPermissionPolicy(
        HealthDataCategory.values.toSet(),
      ),
    );
    final records = pipeline.ingest(
      sourcePlatform: HealthSourcePlatform.healthConnect,
      records: [
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'unitless_event',
          sourceRecordId: 'event-1',
          observedAt: DateTime.utc(2026, 9, 12, 8, 5),
          value: true,
        ),
        RawHealthRecord(
          sourcePlatform: HealthSourcePlatform.healthConnect,
          sourceType: 'unitless_event',
          sourceRecordId: 'event-2',
          observedAt: DateTime.utc(2026, 9, 12, 8, 10),
          value: true,
        ),
      ],
    ).records;
    final aggregator = DeterministicHealthSensorAggregator(
      policyResolver: MapAggregationPolicyResolver([
        const AggregationPolicy(
          policyId: 'unitless-event-hourly-count',
          version: 1,
          canonicalCode: 'wellness.unitless_event',
          method: AggregationMethod.count,
          bucketSize: Duration(hours: 1),
        ),
      ]),
    );

    final result = aggregator
        .aggregate(
          records: records,
          rangeStart: DateTime.utc(2026, 9, 12, 8),
          rangeEnd: DateTime.utc(2026, 9, 12, 9),
        )
        .single;

    expect(result.value, 2);
    expect(result.unit, isNull);
    expect(result.missingness, AggregationMissingness.observed);
    expect(result.conflicts, isEmpty);
  });
}
