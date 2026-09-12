import 'health_ingestion.dart';

enum AggregationMethod {
  mean,
  median,
  min,
  max,
  sum,
  latest,
  earliest,
  duration,
  count,
}

enum AggregationMissingness {
  observed,
  partiallyMissing,
  missing,
}

class AggregationConflict {
  const AggregationConflict({
    required this.reason,
    required this.contributingRecordKeys,
    this.details = const <String, Object?>{},
  });

  final String reason;
  final List<String> contributingRecordKeys;
  final Map<String, Object?> details;
}

class AggregationPolicy {
  const AggregationPolicy({
    required this.policyId,
    required this.version,
    required this.canonicalCode,
    required this.method,
    required this.bucketSize,
    this.conflictTolerance,
  });

  final String policyId;
  final int version;
  final String canonicalCode;
  final AggregationMethod method;
  final Duration bucketSize;
  final num? conflictTolerance;
}

const defaultSensorAggregationPolicies = <AggregationPolicy>[
  AggregationPolicy(
    policyId: 'heart-rate-hourly-mean',
    version: 1,
    canonicalCode: 'vital.heart_rate',
    method: AggregationMethod.mean,
    bucketSize: Duration(hours: 1),
  ),
  AggregationPolicy(
    policyId: 'resting-heart-rate-daily-latest',
    version: 1,
    canonicalCode: 'vital.resting_heart_rate',
    method: AggregationMethod.latest,
    bucketSize: Duration(days: 1),
  ),
  AggregationPolicy(
    policyId: 'spo2-hourly-mean',
    version: 1,
    canonicalCode: 'vital.oxygen_saturation',
    method: AggregationMethod.mean,
    bucketSize: Duration(hours: 1),
    conflictTolerance: 3,
  ),
  AggregationPolicy(
    policyId: 'blood-pressure-systolic-hourly-latest',
    version: 1,
    canonicalCode: 'vital.blood_pressure.systolic',
    method: AggregationMethod.latest,
    bucketSize: Duration(hours: 1),
  ),
  AggregationPolicy(
    policyId: 'blood-pressure-diastolic-hourly-latest',
    version: 1,
    canonicalCode: 'vital.blood_pressure.diastolic',
    method: AggregationMethod.latest,
    bucketSize: Duration(hours: 1),
  ),
  AggregationPolicy(
    policyId: 'body-temperature-hourly-latest',
    version: 1,
    canonicalCode: 'vital.body_temperature',
    method: AggregationMethod.latest,
    bucketSize: Duration(hours: 1),
  ),
  AggregationPolicy(
    policyId: 'respiratory-rate-hourly-mean',
    version: 1,
    canonicalCode: 'vital.respiratory_rate',
    method: AggregationMethod.mean,
    bucketSize: Duration(hours: 1),
  ),
  AggregationPolicy(
    policyId: 'sleep-daily-duration',
    version: 1,
    canonicalCode: 'sleep.session',
    method: AggregationMethod.duration,
    bucketSize: Duration(days: 1),
  ),
  AggregationPolicy(
    policyId: 'steps-daily-sum',
    version: 1,
    canonicalCode: 'activity.steps',
    method: AggregationMethod.sum,
    bucketSize: Duration(days: 1),
  ),
  AggregationPolicy(
    policyId: 'weight-daily-latest',
    version: 1,
    canonicalCode: 'body.weight',
    method: AggregationMethod.latest,
    bucketSize: Duration(days: 1),
  ),
  AggregationPolicy(
    policyId: 'menstruation-flow-daily-latest',
    version: 1,
    canonicalCode: 'reproductive.menstruation.flow',
    method: AggregationMethod.latest,
    bucketSize: Duration(days: 1),
  ),
];

class AggregatedHealthRecord {
  const AggregatedHealthRecord({
    required this.canonicalCode,
    required this.bucketStart,
    required this.bucketEnd,
    required this.value,
    required this.unit,
    required this.policyId,
    required this.policyVersion,
    required this.contributingRecords,
    required this.missingness,
    this.conflicts = const <AggregationConflict>[],
  });

  final String canonicalCode;
  final DateTime bucketStart;
  final DateTime bucketEnd;
  final Object? value;
  final String? unit;
  final String policyId;
  final int policyVersion;
  final List<NormalizedHealthRecord> contributingRecords;
  final AggregationMissingness missingness;
  final List<AggregationConflict> conflicts;

  bool get hasConflict => conflicts.isNotEmpty;

  List<String> get contributingRecordKeys => List.unmodifiable(
        contributingRecords.map((record) => record.deduplicationKey),
      );
}

abstract interface class AggregationPolicyResolver {
  AggregationPolicy? policyFor(String canonicalCode);
}

class MapAggregationPolicyResolver implements AggregationPolicyResolver {
  MapAggregationPolicyResolver(Iterable<AggregationPolicy> policies)
      : _policies = {
          for (final policy in policies) policy.canonicalCode: policy,
        };

  final Map<String, AggregationPolicy> _policies;

  @override
  AggregationPolicy? policyFor(String canonicalCode) =>
      _policies[canonicalCode];
}

class AggregationBucket {
  const AggregationBucket({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}

class DeterministicTimeBucketStrategy {
  const DeterministicTimeBucketStrategy();

  AggregationBucket bucketFor({
    required DateTime observedAt,
    required DateTime rangeStart,
    required Duration bucketSize,
  }) {
    if (bucketSize <= Duration.zero) {
      throw ArgumentError.value(
        bucketSize,
        'bucketSize',
        'must be greater than zero',
      );
    }

    final start = rangeStart.toUtc();
    final observed = observedAt.toUtc();
    final elapsedMicros = observed.difference(start).inMicroseconds;
    if (elapsedMicros < 0) {
      throw ArgumentError.value(
        observedAt,
        'observedAt',
        'must not be before rangeStart',
      );
    }

    final bucketMicros = bucketSize.inMicroseconds;
    final bucketIndex = elapsedMicros ~/ bucketMicros;
    final bucketStart = start.add(
      Duration(microseconds: bucketIndex * bucketMicros),
    );

    return AggregationBucket(
      start: bucketStart,
      end: bucketStart.add(bucketSize),
    );
  }
}

class SensorAggregationGroup {
  const SensorAggregationGroup({
    required this.policy,
    required this.bucket,
    required this.records,
  });

  final AggregationPolicy policy;
  final AggregationBucket bucket;
  final List<NormalizedHealthRecord> records;
}

class DeterministicSensorGrouper {
  DeterministicSensorGrouper({
    required this.policyResolver,
    DeterministicTimeBucketStrategy? bucketStrategy,
  }) : bucketStrategy =
            bucketStrategy ?? const DeterministicTimeBucketStrategy();

  final AggregationPolicyResolver policyResolver;
  final DeterministicTimeBucketStrategy bucketStrategy;

  List<SensorAggregationGroup> group({
    required Iterable<NormalizedHealthRecord> records,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final start = rangeStart.toUtc();
    final end = rangeEnd.toUtc();
    if (!end.isAfter(start)) {
      throw ArgumentError('rangeEnd must be after rangeStart');
    }

    final groups = <String, _MutableSensorAggregationGroup>{};
    for (final record in records) {
      final observed = record.source.observedAt.toUtc();
      if (observed.isBefore(start) || !observed.isBefore(end)) continue;

      final policy = policyResolver.policyFor(record.mapping.canonicalCode);
      if (policy == null) continue;

      final bucket = bucketStrategy.bucketFor(
        observedAt: observed,
        rangeStart: start,
        bucketSize: policy.bucketSize,
      );
      final key =
          '${policy.policyId}|${policy.version}|${policy.canonicalCode}|${bucket.start.microsecondsSinceEpoch}';
      final group = groups.putIfAbsent(
        key,
        () => _MutableSensorAggregationGroup(policy: policy, bucket: bucket),
      );
      group.records.add(record);
    }

    final result = groups.values.toList()
      ..sort((a, b) {
        final timeOrder = a.bucket.start.compareTo(b.bucket.start);
        if (timeOrder != 0) return timeOrder;
        return a.policy.canonicalCode.compareTo(b.policy.canonicalCode);
      });

    return List.unmodifiable(
      result.map((group) {
        group.records.sort((a, b) {
          final timeOrder = a.source.observedAt.toUtc().compareTo(
                b.source.observedAt.toUtc(),
              );
          if (timeOrder != 0) return timeOrder;
          return a.deduplicationKey.compareTo(b.deduplicationKey);
        });
        return SensorAggregationGroup(
          policy: group.policy,
          bucket: group.bucket,
          records: List.unmodifiable(group.records),
        );
      }),
    );
  }
}

class _MutableSensorAggregationGroup {
  _MutableSensorAggregationGroup({
    required this.policy,
    required this.bucket,
  });

  final AggregationPolicy policy;
  final AggregationBucket bucket;
  final List<NormalizedHealthRecord> records = <NormalizedHealthRecord>[];
}

abstract interface class HealthSensorAggregator {
  List<AggregatedHealthRecord> aggregate({
    required Iterable<NormalizedHealthRecord> records,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}

class DeterministicHealthSensorAggregator implements HealthSensorAggregator {
  DeterministicHealthSensorAggregator({
    required AggregationPolicyResolver policyResolver,
    DeterministicSensorGrouper? grouper,
  }) : grouper = grouper ??
            DeterministicSensorGrouper(
              policyResolver: policyResolver,
            );

  final DeterministicSensorGrouper grouper;

  @override
  List<AggregatedHealthRecord> aggregate({
    required Iterable<NormalizedHealthRecord> records,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final groups = grouper.group(
      records: records,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    return List.unmodifiable(groups.map(_aggregateGroup));
  }

  AggregatedHealthRecord _aggregateGroup(SensorAggregationGroup group) {
    final records = group.records;
    final values = records
        .map((record) => record.normalizedValue)
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList(growable: false);
    final units = records
        .map((record) => record.normalizedUnit)
        .whereType<String>()
        .toSet();
    final unitsConsistent = units.length <= 1;
    final hasPartiallyMissingUnit = units.isNotEmpty &&
        records.any((record) => record.normalizedUnit == null);
    final conflicts = _detectConflicts(group, units, values);

    final value = unitsConsistent
        ? switch (group.policy.method) {
            AggregationMethod.mean => _mean(values),
            AggregationMethod.median => _median(values),
            AggregationMethod.min => _min(values),
            AggregationMethod.max => _max(values),
            AggregationMethod.sum => _sum(values),
            AggregationMethod.latest =>
              records.isEmpty ? null : records.last.normalizedValue,
            AggregationMethod.earliest =>
              records.isEmpty ? null : records.first.normalizedValue,
            AggregationMethod.duration => _duration(records),
            AggregationMethod.count => records.length,
          }
        : null;

    final supportsNonNumeric =
        group.policy.method == AggregationMethod.latest ||
            group.policy.method == AggregationMethod.earliest ||
            group.policy.method == AggregationMethod.count ||
            group.policy.method == AggregationMethod.duration;
    final missingness = records.isEmpty
        ? AggregationMissingness.missing
        : !unitsConsistent ||
                hasPartiallyMissingUnit ||
                (!supportsNonNumeric && values.length != records.length)
            ? AggregationMissingness.partiallyMissing
            : AggregationMissingness.observed;

    return AggregatedHealthRecord(
      canonicalCode: group.policy.canonicalCode,
      bucketStart: group.bucket.start,
      bucketEnd: group.bucket.end,
      value: value,
      unit: unitsConsistent && units.isNotEmpty ? units.single : null,
      policyId: group.policy.policyId,
      policyVersion: group.policy.version,
      contributingRecords: records,
      missingness: missingness,
      conflicts: conflicts,
    );
  }

  List<AggregationConflict> _detectConflicts(
    SensorAggregationGroup group,
    Set<String> units,
    List<double> values,
  ) {
    final conflicts = <AggregationConflict>[];
    if (units.length > 1) {
      conflicts.add(
        AggregationConflict(
          reason: 'unit_mismatch',
          contributingRecordKeys: List.unmodifiable(
            group.records.map((record) => record.deduplicationKey),
          ),
          details: <String, Object?>{
            'units': List<String>.unmodifiable(units.toList()..sort()),
          },
        ),
      );
    }

    final tolerance = group.policy.conflictTolerance?.toDouble();
    if (tolerance != null && values.length > 1) {
      if (tolerance < 0) {
        throw ArgumentError.value(
          group.policy.conflictTolerance,
          'conflictTolerance',
          'must not be negative',
        );
      }
      final minimum = _min(values)!;
      final maximum = _max(values)!;
      final spread = maximum - minimum;
      if (spread > tolerance) {
        conflicts.add(
          AggregationConflict(
            reason: 'value_disagreement',
            contributingRecordKeys: List.unmodifiable(
              group.records.map((record) => record.deduplicationKey),
            ),
            details: <String, Object?>{
              'min': minimum,
              'max': maximum,
              'spread': spread,
              'tolerance': tolerance,
            },
          ),
        );
      }
    }

    return List.unmodifiable(conflicts);
  }

  double? _mean(List<double> values) {
    if (values.isEmpty) return null;
    return _sum(values)! / values.length;
  }

  double? _median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = List<double>.of(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double? _sum(List<double> values) {
    if (values.isEmpty) return null;
    var total = 0.0;
    for (final value in values) {
      total += value;
    }
    return total;
  }

  double? _min(List<double> values) {
    if (values.isEmpty) return null;
    var result = values.first;
    for (final value in values.skip(1)) {
      if (value < result) result = value;
    }
    return result;
  }

  double? _max(List<double> values) {
    if (values.isEmpty) return null;
    var result = values.first;
    for (final value in values.skip(1)) {
      if (value > result) result = value;
    }
    return result;
  }

  Object? _duration(List<NormalizedHealthRecord> records) {
    if (records.isEmpty) return null;
    final durations = records
        .map((record) => record.normalizedValue)
        .whereType<Duration>()
        .toList(growable: false);
    if (durations.length == records.length) {
      var totalMicros = 0;
      for (final duration in durations) {
        totalMicros += duration.inMicroseconds;
      }
      return Duration(microseconds: totalMicros);
    }

    final numeric = records
        .map((record) => record.normalizedValue)
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList(growable: false);
    return numeric.length == records.length ? _sum(numeric) : null;
  }
}
