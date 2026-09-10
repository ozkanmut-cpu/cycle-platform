import 'package:cycle_core_domain/cycle_core_domain.dart';

class ImportedHealthEventRevisionPlan {
  const ImportedHealthEventRevisionPlan({
    required this.snapshot,
    required this.current,
  });

  final HealthEvent snapshot;
  final HealthEvent current;
}

class ImportedHealthEventRevision {
  const ImportedHealthEventRevision._();

  static ImportedHealthEventRevisionPlan? plan({
    required HealthEvent existing,
    required HealthEvent incoming,
  }) {
    if (sameObservation(existing, incoming)) return null;

    final revisionId =
        '${existing.id}:revision:${existing.temporal.recordedAt.toUtc().microsecondsSinceEpoch}';
    final snapshot = copy(existing, id: revisionId);
    final current = copy(incoming, supersedesEventId: revisionId);
    return ImportedHealthEventRevisionPlan(
      snapshot: snapshot,
      current: current,
    );
  }

  static bool sameObservation(HealthEvent left, HealthEvent right) {
    return left.subjectId == right.subjectId &&
        left.eventType == right.eventType &&
        left.episodeId == right.episodeId &&
        left.value == right.value &&
        left.unit == right.unit &&
        left.severity == right.severity &&
        left.bodyLocation == right.bodyLocation &&
        left.dataState == right.dataState &&
        left.temporal.observedAt.toUtc() == right.temporal.observedAt.toUtc() &&
        left.provenance.sourceKind == right.provenance.sourceKind &&
        left.provenance.sourceName == right.provenance.sourceName &&
        left.provenance.sourceRecordId == right.provenance.sourceRecordId &&
        left.provenance.deviceName == right.provenance.deviceName &&
        left.provenance.measurementMethod ==
            right.provenance.measurementMethod &&
        left.verificationStatus == right.verificationStatus &&
        left.confidence == right.confidence &&
        left.privacyClass == right.privacyClass &&
        left.schemaVersion == right.schemaVersion;
  }

  static HealthEvent copy(
    HealthEvent event, {
    String? id,
    String? supersedesEventId,
  }) {
    return HealthEvent(
      id: id ?? event.id,
      subjectId: event.subjectId,
      eventType: event.eventType,
      temporal: event.temporal,
      provenance: event.provenance,
      verificationStatus: event.verificationStatus,
      confidence: event.confidence,
      privacyClass: event.privacyClass,
      schemaVersion: event.schemaVersion,
      episodeId: event.episodeId,
      value: event.value,
      unit: event.unit,
      severity: event.severity,
      bodyLocation: event.bodyLocation,
      dataState: event.dataState,
      cycleContext: event.cycleContext,
      pregnancyContext: event.pregnancyContext,
      visibilityPolicyId: event.visibilityPolicyId,
      backupPolicyId: event.backupPolicyId,
      supersedesEventId: supersedesEventId ?? event.supersedesEventId,
      relatedEventIds: event.relatedEventIds,
    );
  }
}
