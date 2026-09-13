import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_patient/connected_health_screen.dart';
import 'package:cycle_patient/connected_health_view_model_builder.dart';
import 'package:flutter_test/flutter_test.dart';

HealthEvent event({
  required String id,
  required String eventType,
  required num value,
  required String unit,
  required DateTime observedAt,
  required SourceKind sourceKind,
}) {
  return HealthEvent(
    id: id,
    subjectId: 'local-owner',
    eventType: eventType,
    value: value,
    unit: unit,
    dataState: DataState.yes,
    temporal: TemporalMetadata(
      observedAt: observedAt,
      recordedAt: observedAt,
      knownAt: observedAt,
    ),
    provenance: Provenance(sourceKind: sourceKind, sourceRecordId: id),
    verificationStatus: VerificationStatus.deviceMeasured,
    confidence: ConfidenceClass.high,
    privacyClass: 'health',
    schemaVersion: 1,
  );
}

void main() {
  test('uses sensor aggregation and preserves cross-source conflict', () {
    final viewModel = ConnectedHealthViewModelBuilder().build(
      events: [
        event(
          id: 'hc-spo2',
          eventType: 'vital.oxygen_saturation',
          value: 98,
          unit: '%',
          observedAt: DateTime.utc(2026, 9, 13, 8, 5),
          sourceKind: SourceKind.healthConnect,
        ),
        event(
          id: 'hk-spo2',
          eventType: 'vital.oxygen_saturation',
          value: 91,
          unit: '%',
          observedAt: DateTime.utc(2026, 9, 13, 8, 6),
          sourceKind: SourceKind.healthKit,
        ),
      ],
    );

    final spo2 = viewModel.metrics.singleWhere(
      (metric) => metric.label == 'SpO2',
    );
    expect(spo2.state, ConnectedHealthMetricState.conflicting);
    expect(spo2.value, 94.5);
    expect(spo2.sourceLabel, 'Health Connect + HealthKit');
    expect(
      viewModel.sources.where(
        (source) => source.state == ConnectedHealthSourceState.available,
      ),
      hasLength(2),
    );
  });

  test('does not convert absent supported metrics to zero', () {
    final viewModel = ConnectedHealthViewModelBuilder().build(
      events: [
        event(
          id: 'hc-hr',
          eventType: 'vital.heart_rate',
          value: 72,
          unit: 'bpm',
          observedAt: DateTime.utc(2026, 9, 13, 8),
          sourceKind: SourceKind.healthConnect,
        ),
      ],
    );

    final heartRate = viewModel.metrics.singleWhere(
      (metric) => metric.label == 'Heart rate',
    );
    final restingHeartRate = viewModel.metrics.singleWhere(
      (metric) => metric.label == 'Resting heart rate',
    );

    expect(heartRate.state, ConnectedHealthMetricState.observed);
    expect(heartRate.value, 72.0);
    expect(restingHeartRate.state, ConnectedHealthMetricState.missing);
    expect(restingHeartRate.value, isNull);
  });

  test(
    'returns an empty metric view when no connected-source events exist',
    () {
      final viewModel = ConnectedHealthViewModelBuilder().build(
        events: [
          event(
            id: 'manual-hr',
            eventType: 'vital.heart_rate',
            value: 70,
            unit: 'bpm',
            observedAt: DateTime.utc(2026, 9, 13, 8),
            sourceKind: SourceKind.patient,
          ),
        ],
      );

      expect(viewModel.metrics, isEmpty);
      expect(viewModel.isEmpty, isTrue);
    },
  );
}
