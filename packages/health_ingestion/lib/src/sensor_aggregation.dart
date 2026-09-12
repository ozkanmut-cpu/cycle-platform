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

abstract interface class HealthSensorAggregator {
  List<AggregatedHealthRecord> aggregate({
    required Iterable<NormalizedHealthRecord> records,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}
