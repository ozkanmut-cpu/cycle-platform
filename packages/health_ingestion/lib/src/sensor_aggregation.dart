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
  }) : bucketStrategy = bucketStrategy ?? const DeterministicTimeBucketStrategy();

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
      final key = '${policy.canonicalCode}|${bucket.start.microsecondsSinceEpoch}';
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
  }) : grouper = grouper ?? DeterministicSensorGrouper(
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

    final value = switch (group.policy.method) {
      AggregationMethod.mean => _mean(values),
      AggregationMethod.min => _min(values),
      AggregationMethod.max => _max(values),
      AggregationMethod.sum => _sum(values),
      AggregationMethod.latest =>
        records.isEmpty ? null : records.last.normalizedValue,
      AggregationMethod.earliest =>
        records.isEmpty ? null : records.first.normalizedValue,
      AggregationMethod.count => records.length,
      AggregationMethod.median => null,
      AggregationMethod.duration => null,
    };

    final missingness = records.isEmpty
        ? AggregationMissingness.missing
        : values.length == records.length ||
                group.policy.method == AggregationMethod.latest ||
                group.policy.method == AggregationMethod.earliest ||
                group.policy.method == AggregationMethod.count
            ? AggregationMissingness.observed
            : AggregationMissingness.partiallyMissing;

    return AggregatedHealthRecord(
      canonicalCode: group.policy.canonicalCode,
      bucketStart: group.bucket.start,
      bucketEnd: group.bucket.end,
      value: value,
      unit: records.isEmpty ? null : records.first.normalizedUnit,
      policyId: group.policy.policyId,
      policyVersion: group.policy.version,
      contributingRecords: records,
      missingness: missingness,
    );
  }

  double? _mean(List<double> values) {
    if (values.isEmpty) return null;
    return _sum(values)! / values.length;
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
}
