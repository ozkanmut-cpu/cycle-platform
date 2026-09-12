import 'health_ingestion.dart';

class NearDuplicateGroup {
  const NearDuplicateGroup({
    required this.canonicalCode,
    required this.records,
    required this.timeWindow,
    required this.valueTolerance,
  });

  final String canonicalCode;
  final List<NormalizedHealthRecord> records;
  final Duration timeWindow;
  final num valueTolerance;

  List<String> get recordKeys => List.unmodifiable(
        records.map((record) => record.deduplicationKey),
      );
}

class DeterministicNearDuplicateDetector {
  const DeterministicNearDuplicateDetector({
    this.timeWindow = const Duration(seconds: 30),
    this.valueTolerance = 0,
  });

  final Duration timeWindow;
  final num valueTolerance;

  List<NearDuplicateGroup> detect(
    Iterable<NormalizedHealthRecord> records,
  ) {
    if (timeWindow.isNegative) {
      throw ArgumentError.value(timeWindow, 'timeWindow', 'must not be negative');
    }
    if (valueTolerance < 0) {
      throw ArgumentError.value(
        valueTolerance,
        'valueTolerance',
        'must not be negative',
      );
    }

    final sorted = records.toList()
      ..sort((a, b) {
        final codeOrder =
            a.mapping.canonicalCode.compareTo(b.mapping.canonicalCode);
        if (codeOrder != 0) return codeOrder;
        final timeOrder = a.source.observedAt
            .toUtc()
            .compareTo(b.source.observedAt.toUtc());
        if (timeOrder != 0) return timeOrder;
        return a.deduplicationKey.compareTo(b.deduplicationKey);
      });

    final groups = <NearDuplicateGroup>[];
    var index = 0;
    while (index < sorted.length) {
      final seed = sorted[index];
      final members = <NormalizedHealthRecord>[seed];
      var next = index + 1;
      while (next < sorted.length) {
        final candidate = sorted[next];
        if (candidate.mapping.canonicalCode != seed.mapping.canonicalCode) break;
        final delta = candidate.source.observedAt
            .toUtc()
            .difference(seed.source.observedAt.toUtc())
            .abs();
        if (delta > timeWindow) break;
        if (_valuesEquivalent(seed.normalizedValue, candidate.normalizedValue)) {
          members.add(candidate);
        }
        next++;
      }

      if (members.length > 1) {
        groups.add(
          NearDuplicateGroup(
            canonicalCode: seed.mapping.canonicalCode,
            records: List.unmodifiable(members),
            timeWindow: timeWindow,
            valueTolerance: valueTolerance,
          ),
        );
      }
      index++;
    }

    return List.unmodifiable(groups);
  }

  bool _valuesEquivalent(Object? a, Object? b) {
    if (a is num && b is num) {
      return (a.toDouble() - b.toDouble()).abs() <= valueTolerance;
    }
    return a == b;
  }
}
