import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_health_ingestion/cycle_health_ingestion.dart' as ingestion;
import 'package:cycle_storage/cycle_storage.dart' as storage;
import 'package:cycle_storage_sqlcipher/cycle_storage_sqlcipher.dart';

import 'health_sync_cursor_store.dart';
import 'normalized_health_event_mapper.dart';

abstract interface class PatientHealthImportCommitter {
  Future<void> commit({
    required Iterable<HealthEvent> upserts,
    required Iterable<String> deletedEventIds,
    required Iterable<storage.AuditEvent> auditEvents,
    required storage.PersistedHealthSyncCursor cursor,
    required DateTime deletedAt,
  });
}

class SqlCipherPatientHealthImportCommitter
    implements PatientHealthImportCommitter {
  const SqlCipherPatientHealthImportCommitter(this.delegate);

  final SqlCipherHealthImportCommitter delegate;

  @override
  Future<void> commit({
    required Iterable<HealthEvent> upserts,
    required Iterable<String> deletedEventIds,
    required Iterable<storage.AuditEvent> auditEvents,
    required storage.PersistedHealthSyncCursor cursor,
    required DateTime deletedAt,
  }) => delegate.commit(
    upserts: upserts,
    deletedEventIds: deletedEventIds,
    auditEvents: auditEvents,
    cursor: cursor,
    deletedAt: deletedAt,
  );
}

class PatientHealthImportService {
  const PatientHealthImportService({
    required this.coordinator,
    required this.cursorStore,
    required this.mapper,
    required this.committer,
  });

  final ingestion.HealthImportCoordinator coordinator;
  final PatientHealthSyncCursorStore cursorStore;
  final NormalizedHealthEventMapper mapper;
  final PatientHealthImportCommitter committer;

  Future<ingestion.CoordinatedHealthImportResult> importSource({
    required String subjectId,
    required ingestion.HealthSourceSyncAdapter adapter,
    required DateTime now,
  }) async {
    final timestamp = now.toUtc();
    final previousCursor = await cursorStore.load(
      subjectId: subjectId,
      sourcePlatform: adapter.sourcePlatform,
    );
    final result = await coordinator.import(
      adapter: adapter,
      now: timestamp,
      previousCursor: previousCursor,
    );

    final upserts = result.ingestion.records
        .map(
          (record) => mapper.toHealthEvent(
            subjectId: subjectId,
            record: record,
            importedAt: timestamp,
          ),
        )
        .toList(growable: false);
    final deletedEventIds = result.deletedSourceRecordIds
        .map(
          (sourceRecordId) => mapper.eventIdFor(
            sourcePlatform: adapter.sourcePlatform,
            sourceRecordId: sourceRecordId,
          ),
        )
        .toList(growable: false);
    final auditEvents = <storage.AuditEvent>[
      for (var index = 0; index < upserts.length; index++)
        storage.AuditEvent(
          id:
              'audit:import:${adapter.sourcePlatform.name}:${timestamp.microsecondsSinceEpoch}:$index',
          action: storage.AuditAction.imported,
          occurredAt: timestamp,
          actorId: 'system:health_import',
          subjectType: 'health_event',
          subjectId: upserts[index].id,
          metadata: <String, Object?>{
            'ownerSubjectId': subjectId,
            'eventType': upserts[index].eventType,
            'source': adapter.sourcePlatform.name,
            'sourceRecordId': upserts[index].provenance.sourceRecordId,
          },
        ),
      for (var index = 0; index < deletedEventIds.length; index++)
        storage.AuditEvent(
          id:
              'audit:delete:${adapter.sourcePlatform.name}:${timestamp.microsecondsSinceEpoch}:$index',
          action: storage.AuditAction.deleted,
          occurredAt: timestamp,
          actorId: 'system:health_import',
          subjectType: 'health_event',
          subjectId: deletedEventIds[index],
          metadata: <String, Object?>{
            'ownerSubjectId': subjectId,
            'source': adapter.sourcePlatform.name,
            'sourceRecordId': result.deletedSourceRecordIds[index],
          },
        ),
    ];

    await committer.commit(
      upserts: upserts,
      deletedEventIds: deletedEventIds,
      auditEvents: auditEvents,
      cursor: storage.PersistedHealthSyncCursor(
        subjectId: subjectId,
        source: _storageSource(adapter.sourcePlatform),
        value: result.cursor.token,
        updatedAt: result.cursor.updatedAt,
      ),
      deletedAt: timestamp,
    );

    return result;
  }
}

storage.HealthSyncCursorSource _storageSource(
  ingestion.HealthSourcePlatform sourcePlatform,
) => switch (sourcePlatform) {
  ingestion.HealthSourcePlatform.healthConnect =>
    storage.HealthSyncCursorSource.healthConnect,
  ingestion.HealthSourcePlatform.healthKit =>
    storage.HealthSyncCursorSource.healthKit,
  ingestion.HealthSourcePlatform.other =>
    throw UnsupportedError('Unsupported persistent health sync source.'),
};
