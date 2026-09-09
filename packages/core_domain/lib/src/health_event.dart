import 'data_state.dart';
import 'provenance.dart';
import 'temporal_metadata.dart';

class HealthEvent {
  const HealthEvent({
    required this.id,
    required this.subjectId,
    required this.eventType,
    required this.temporal,
    required this.provenance,
    required this.verificationStatus,
    required this.confidence,
    required this.privacyClass,
    required this.schemaVersion,
    this.episodeId,
    this.value,
    this.unit,
    this.severity,
    this.bodyLocation,
    this.dataState,
    this.cycleContext,
    this.pregnancyContext,
    this.visibilityPolicyId,
    this.backupPolicyId,
    this.supersedesEventId,
    this.relatedEventIds = const <String>[],
  });

  final String id;
  final String subjectId;
  final String eventType;
  final String? episodeId;

  final num? value;
  final String? unit;
  final int? severity;
  final String? bodyLocation;
  final DataState? dataState;

  final Map<String, Object?>? cycleContext;
  final Map<String, Object?>? pregnancyContext;

  final Provenance provenance;
  final VerificationStatus verificationStatus;
  final ConfidenceClass confidence;

  final String privacyClass;
  final String? visibilityPolicyId;
  final String? backupPolicyId;

  final TemporalMetadata temporal;

  final String? supersedesEventId;
  final List<String> relatedEventIds;
  final int schemaVersion;

  bool get isClinicalSource =>
      verificationStatus == VerificationStatus.clinicalSource ||
      verificationStatus == VerificationStatus.clinicianVerified;
}
