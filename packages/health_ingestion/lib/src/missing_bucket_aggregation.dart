import 'health_ingestion.dart';
import 'sensor_aggregation.dart';

class DeterministicMissingBucketAggregator {
  const DeterministicMissingBucketAggregator();

  List<AggregatedHealthRecord> aggregate({
    required HealthSensorAggregator aggregator,
    required Iterable<NormalizedHealthRecord> records,
    required Iterable<AggregationPolicy> policies,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final start = rangeStart.toUtc();
    final end = rangeEnd.toUtc();
    if (!end.isAfter(start)) {
      throw ArgumentError('rangeEnd must be after rangeStart');
    }

    final observed = aggregator.aggregate(
      records: records,
      rangeStart: start,
      rangeEnd: end,
    );
    final observedByKey = <String, AggregatedHealthRecord>{
      for (final record in observed)
        _key(
          policyId: record.policyId,
          policyVersion: record.policyVersion,
          canonicalCode: record.canonicalCode,
          bucketStart: record.bucketStart,
        ): record,
    };

    final result = <AggregatedHealthRecord>[];
    for (final policy in policies) {
      if (policy.bucketSize <= Duration.zero) {
        throw ArgumentError.value(
          policy.bucketSize,
          'policy.bucketSize',
          'must be greater than zero',
        );
      }

      for (var bucketStart = start;
          bucketStart.isBefore(end);
          bucketStart = bucketStart.add(policy.bucketSize)) {
        final nominalBucketEnd = bucketStart.add(policy.bucketSize);
        final key = _key(
          policyId: policy.policyId,
          policyVersion: policy.version,
          canonicalCode: policy.canonicalCode,
          bucketStart: bucketStart,
        );
        result.add(
          observedByKey[key] ??
              AggregatedHealthRecord(
                canonicalCode: policy.canonicalCode,
                bucketStart: bucketStart,
                bucketEnd:
                    nominalBucketEnd.isAfter(end) ? end : nominalBucketEnd,
                value: null,
                unit: null,
                policyId: policy.policyId,
                policyVersion: policy.version,
                contributingRecords: const <NormalizedHealthRecord>[],
                missingness: AggregationMissingness.missing,
              ),
        );
      }
    }

    result.sort((a, b) {
      final timeOrder = a.bucketStart.compareTo(b.bucketStart);
      if (timeOrder != 0) return timeOrder;
      final codeOrder = a.canonicalCode.compareTo(b.canonicalCode);
      if (codeOrder != 0) return codeOrder;
      final policyOrder = a.policyId.compareTo(b.policyId);
      if (policyOrder != 0) return policyOrder;
      return a.policyVersion.compareTo(b.policyVersion);
    });

    return List.unmodifiable(result);
  }

  String _key({
    required String policyId,
    required int policyVersion,
    required String canonicalCode,
    required DateTime bucketStart,
  }) =>
      '$policyId|$policyVersion|$canonicalCode|${bucketStart.toUtc().microsecondsSinceEpoch}';
}
