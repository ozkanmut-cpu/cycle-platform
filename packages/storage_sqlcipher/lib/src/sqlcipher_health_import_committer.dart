import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_storage/cycle_storage.dart';

import 'sqlcipher_audit_log_repository.dart';
import 'sqlcipher_database.dart';
import 'sqlcipher_health_event_repository.dart';
import 'sqlcipher_health_sync_cursor_repository.dart';

class SqlCipherHealthImportCommitter {
  SqlCipherHealthImportCommitter(this._db)
    : _healthEvents = SqlCipherHealthEventRepository(_db),
      _auditLog = SqlCipherAuditLogRepository(_db),
      _cursors = SqlCipherHealthSyncCursorRepository(_db);

  final SqlCipherDatabase _db;
  final SqlCipherHealthEventRepository _healthEvents;
  final SqlCipherAuditLogRepository _auditLog;
  final SqlCipherHealthSyncCursorRepository _cursors;

  Future<void> commit({
    required Iterable<HealthEvent> upserts,
    required Iterable<String> deletedEventIds,
    required Iterable<AuditEvent> auditEvents,
    required PersistedHealthSyncCursor cursor,
    required DateTime deletedAt,
  }) async {
    await _db.database.transaction((transaction) async {
      for (final event in upserts) {
        final existing = await _healthEvents.getByIdWithExecutor(
          transaction,
          event.id,
        );
        var eventToWrite = event;

        if (existing != null && !_sameImportedObservation(existing, event)) {
          final revisionId = _revisionId(existing);
          await _healthEvents.upsertWithExecutor(
            transaction,
            _copyHealthEvent(existing, id: revisionId),
          );
          eventToWrite = _copyHealthEvent(
            event,
            supersedesEventId: revisionId,
          );
        }

        await _healthEvents.upsertWithExecutor(transaction, eventToWrite);
      }
      for (final eventId in deletedEventIds) {
        await _healthEvents.markDeletedWithExecutor(
          transaction,
          eventId: eventId,
          deletedAt: deletedAt,
        );
      }
      for (final auditEvent in auditEvents) {
        await _auditLog.appendWithExecutor(transaction, auditEvent);
      }

      // Advance the source cursor only after every event/audit mutation has
      // succeeded. A failure above rolls the whole SQLCipher transaction back.
      await _cursors.saveWithExecutor(transaction, cursor);
    });
  }
}

String _revisionId(HealthEvent event) =>
    '${event.id}:revision:${event.temporal.recordedAt.toUtc().microsecondsSinceEpoch}';

bool _sameImportedObservation(HealthEvent left, HealthEvent right) {
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

HealthEvent _copyHealthEvent(
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
