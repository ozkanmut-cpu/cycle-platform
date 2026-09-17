import 'package:cycle_core_domain/cycle_core_domain.dart';

void _requireUtc(DateTime value) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, 'virtualNow', 'must be UTC');
  }
}

HealthEvent patientJourneyEvent({
  required String id,
  required String eventType,
  required DateTime observedAt,
  num? value,
  String? unit,
  int? severity,
  SourceKind sourceKind = SourceKind.patient,
  String privacyClass = 'reproductive',
}) => HealthEvent(
  id: id,
  subjectId: 'local-owner',
  eventType: eventType,
  value: value,
  unit: unit,
  severity: severity,
  dataState: DataState.yes,
  temporal: TemporalMetadata(
    observedAt: observedAt,
    recordedAt: observedAt,
    knownAt: observedAt,
  ),
  provenance: Provenance(sourceKind: sourceKind, sourceRecordId: id),
  verificationStatus: sourceKind == SourceKind.patient
      ? VerificationStatus.selfReported
      : VerificationStatus.deviceMeasured,
  confidence: ConfidenceClass.high,
  privacyClass: privacyClass,
  schemaVersion: 1,
);

List<HealthEvent> p001Events(DateTime virtualNow) {
  _requireUtc(virtualNow);
  return <HealthEvent>[
    patientJourneyEvent(
      id: 'P-001-period-start-20260905',
      eventType: 'menstruation.period_start',
      observedAt: DateTime.utc(2026, 9, 5, 9),
    ),
    patientJourneyEvent(
      id: 'P-001-cramps-20260905',
      eventType: 'symptom.cramps',
      observedAt: DateTime.utc(2026, 9, 5, 10),
      severity: 2,
    ),
  ];
}

List<HealthEvent> p002Events(DateTime virtualNow) {
  _requireUtc(virtualNow);
  return <HealthEvent>[
    patientJourneyEvent(
      id: 'P-002-spo2-health-connect',
      eventType: 'vital.oxygen_saturation',
      observedAt: DateTime.utc(2026, 9, 17, 8),
      value: 98,
      unit: '%',
      sourceKind: SourceKind.healthConnect,
      privacyClass: 'health',
    ),
    patientJourneyEvent(
      id: 'P-002-spo2-healthkit',
      eventType: 'vital.oxygen_saturation',
      observedAt: DateTime.utc(2026, 9, 17, 8, 1),
      value: 91,
      unit: '%',
      sourceKind: SourceKind.healthKit,
      privacyClass: 'health',
    ),
  ];
}

List<HealthEvent> p005Events(DateTime virtualNow) {
  _requireUtc(virtualNow);
  return <HealthEvent>[
    patientJourneyEvent(
      id: 'P-005-sensitive-headache',
      eventType: 'symptom.headache',
      observedAt: DateTime.utc(2026, 9, 17, 7),
    ),
  ];
}
