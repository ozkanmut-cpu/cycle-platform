import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_storage/cycle_storage.dart';

import 'imported_health_event_revision.dart';
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

        if (existing != null) {
          final revision = ImportedHealthEventRevision.plan(
            existing: existing,
            incoming: event,
          );
          if (revision != null) {
            await _healthEvents.upsertWithExecutor(
              transaction,
              revision.snapshot,
            );
            eventToWrite = revision.current;
          }
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
