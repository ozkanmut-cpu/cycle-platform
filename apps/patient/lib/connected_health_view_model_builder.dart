import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';

import 'connected_health_screen.dart';

class ConnectedHealthViewModelBuilder {
  ConnectedHealthViewModelBuilder({HealthSensorAggregator? aggregator})
    : aggregator =
          aggregator ??
          DeterministicHealthSensorAggregator(
            policyResolver: MapAggregationPolicyResolver(
              defaultSensorAggregationPolicies,
            ),
          );

  final HealthSensorAggregator aggregator;

  ConnectedHealthViewModel build({required Iterable<HealthEvent> events}) {
    final connectedEvents = events
        .where((event) => _platformFor(event.provenance.sourceKind) != null)
        .toList(growable: false);

    final sources = <ConnectedHealthSourceSummary>[
      ConnectedHealthSourceSummary(
        name: 'Health Connect',
        state:
            connectedEvents.any(
              (event) =>
                  event.provenance.sourceKind == SourceKind.healthConnect,
            )
            ? ConnectedHealthSourceState.available
            : ConnectedHealthSourceState.unavailable,
      ),
      ConnectedHealthSourceSummary(
        name: 'HealthKit',
        state:
            connectedEvents.any(
              (event) => event.provenance.sourceKind == SourceKind.healthKit,
            )
            ? ConnectedHealthSourceState.available
            : ConnectedHealthSourceState.unavailable,
      ),
    ];

    if (connectedEvents.isEmpty) {
      return ConnectedHealthViewModel(sources: sources);
    }

    final mappingsByCanonicalCode = <String, HealthTypeMapping>{
      for (final mapping in defaultHealthMappings)
        mapping.canonicalCode: mapping,
    };
    final normalizedRecords = <NormalizedHealthRecord>[];
    for (final event in connectedEvents) {
      final mapping = mappingsByCanonicalCode[event.eventType];
      final platform = _platformFor(event.provenance.sourceKind);
      if (mapping == null || platform == null) continue;

      normalizedRecords.add(
        NormalizedHealthRecord(
          source: RawHealthRecord(
            sourcePlatform: platform,
            sourceType: mapping.sourceType,
            sourceRecordId: event.provenance.sourceRecordId ?? event.id,
            observedAt: event.temporal.observedAt.toUtc(),
            value: event.value,
            unit: event.unit,
            sourceName: event.provenance.sourceName,
            deviceName: event.provenance.deviceName,
            metadata: event.provenance.metadata ?? const <String, Object?>{},
          ),
          mapping: mapping,
          normalizedValue: event.value,
          normalizedUnit: event.unit,
          provenance: event.provenance,
        ),
      );
    }

    if (normalizedRecords.isEmpty) {
      return ConnectedHealthViewModel(sources: sources);
    }

    var rangeStart = normalizedRecords.first.source.observedAt.toUtc();
    var rangeEnd = rangeStart;
    for (final record in normalizedRecords.skip(1)) {
      final observedAt = record.source.observedAt.toUtc();
      if (observedAt.isBefore(rangeStart)) rangeStart = observedAt;
      if (observedAt.isAfter(rangeEnd)) rangeEnd = observedAt;
    }
    rangeEnd = rangeEnd.add(const Duration(microseconds: 1));

    final aggregates = aggregator.aggregate(
      records: normalizedRecords,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    final latestByCanonicalCode = <String, AggregatedHealthRecord>{};
    for (final aggregate in aggregates) {
      final current = latestByCanonicalCode[aggregate.canonicalCode];
      if (current == null ||
          aggregate.bucketStart.isAfter(current.bucketStart)) {
        latestByCanonicalCode[aggregate.canonicalCode] = aggregate;
      }
    }

    final metrics = <ConnectedHealthMetricSummary>[];
    for (final policy in defaultSensorAggregationPolicies) {
      final aggregate = latestByCanonicalCode[policy.canonicalCode];
      if (aggregate == null) {
        metrics.add(
          ConnectedHealthMetricSummary(
            label: _labelFor(policy.canonicalCode),
            state: ConnectedHealthMetricState.missing,
          ),
        );
        continue;
      }

      metrics.add(
        ConnectedHealthMetricSummary(
          label: _labelFor(policy.canonicalCode),
          state: aggregate.hasConflict
              ? ConnectedHealthMetricState.conflicting
              : aggregate.missingness == AggregationMissingness.observed
              ? ConnectedHealthMetricState.observed
              : ConnectedHealthMetricState.missing,
          value: aggregate.value,
          unit: aggregate.unit,
          sourceLabel: _sourceLabel(aggregate.contributingRecords),
        ),
      );
    }

    return ConnectedHealthViewModel(sources: sources, metrics: metrics);
  }
}

HealthSourcePlatform? _platformFor(SourceKind sourceKind) =>
    switch (sourceKind) {
      SourceKind.healthConnect => HealthSourcePlatform.healthConnect,
      SourceKind.healthKit => HealthSourcePlatform.healthKit,
      _ => null,
    };

String? _sourceLabel(Iterable<NormalizedHealthRecord> records) {
  final labels =
      records
          .map(
            (record) => switch (record.source.sourcePlatform) {
              HealthSourcePlatform.healthConnect => 'Health Connect',
              HealthSourcePlatform.healthKit => 'HealthKit',
              HealthSourcePlatform.other => null,
            },
          )
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
  return labels.isEmpty ? null : labels.join(' + ');
}

String _labelFor(String canonicalCode) => switch (canonicalCode) {
  'vital.heart_rate' => 'Heart rate',
  'vital.resting_heart_rate' => 'Resting heart rate',
  'vital.oxygen_saturation' => 'SpO2',
  'vital.blood_pressure.systolic' => 'Blood pressure · systolic',
  'vital.blood_pressure.diastolic' => 'Blood pressure · diastolic',
  'vital.body_temperature' => 'Body temperature',
  'vital.respiratory_rate' => 'Respiratory rate',
  'sleep.session' => 'Sleep',
  'activity.steps' => 'Steps',
  'body.weight' => 'Weight',
  'reproductive.menstruation.flow' => 'Menstruation flow',
  _ => canonicalCode,
};
