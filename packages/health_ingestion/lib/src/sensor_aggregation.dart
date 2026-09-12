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

abstract interface class HealthSensorAggregator {
  List<AggregatedHealthRecord> aggregate({
    required Iterable<NormalizedHealthRecord> records,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}
