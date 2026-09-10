import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_health_ingestion/cycle_health_ingestion.dart'
    as ingestion;
import 'package:cycle_patient/health/health_sync_cursor_store.dart';
import 'package:cycle_patient/health/normalized_health_event_mapper.dart';
import 'package:cycle_patient/health/patient_health_import_service.dart';
import 'package:cycle_storage/cycle_storage.dart' as storage;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'full refresh commits normalized event, history and cursor together',
    () async {
      final cursorRepository = _MemoryCursorRepository();
      final commitSink = _FakeCommitter();
      final service = _service(cursorRepository, commitSink);
      final now = DateTime.utc(2026, 9, 9, 20);

      final result = await service.importSource(
        subjectId: 'local-owner',
        adapter: _FakeAdapter.initial(),
        now: now,
      );

      expect(result.usedFullRefresh, isTrue);
      expect(commitSink.upserts, hasLength(1));
      expect(commitSink.upserts.single.id, 'import:healthConnect:weight-1');
      expect(commitSink.upserts.single.eventType, 'body.weight');
      expect(commitSink.cursor?.value, 'token-1');
      expect(commitSink.history?.source, storage.HealthImportSource.healthConnect);
      expect(commitSink.history?.imported, 1);
      expect(commitSink.history?.deleted, 0);
      expect(commitSink.history?.usedFullRefresh, isTrue);
      expect(
        commitSink.auditEvents.single.action,
        storage.AuditAction.imported,
      );
    },
  );

  test('incremental deletion maps tombstone, history and cursor', () async {
    final cursorRepository = _MemoryCursorRepository();
    await cursorRepository.save(
      storage.PersistedHealthSyncCursor(
        subjectId: 'local-owner',
        source: storage.HealthSyncCursorSource.healthConnect,
        value: 'token-1',
        updatedAt: DateTime.utc(2026, 9, 9, 19),
      ),
    );
    final commitSink = _FakeCommitter();
    final service = _service(cursorRepository, commitSink);

    final result = await service.importSource(
      subjectId: 'local-owner',
      adapter: _FakeAdapter.incrementalDelete(),
      now: DateTime.utc(2026, 9, 9, 20),
    );

    expect(result.usedFullRefresh, isFalse);
    expect(commitSink.deletedEventIds, ['import:healthConnect:weight-1']);
    expect(commitSink.cursor?.value, 'token-2');
    expect(commitSink.history?.imported, 0);
    expect(commitSink.history?.deleted, 1);
    expect(commitSink.history?.usedFullRefresh, isFalse);
    expect(commitSink.auditEvents.single.action, storage.AuditAction.deleted);
  });
}

PatientHealthImportService _service(
  storage.HealthSyncCursorRepository cursorRepository,
  PatientHealthImportCommitter committer,
) {
  return PatientHealthImportService(
    coordinator: ingestion.HealthImportCoordinator(
      synchronizer: const ingestion.HealthSourceSynchronizer(),
      pipeline: ingestion.HealthIngestionPipeline(
        mappings: ingestion.defaultHealthMappings,
        permissionPolicy: ingestion.AllowlistedImportPermissionPolicy({
          ingestion.HealthDataCategory.body,
        }),
      ),
    ),
    cursorStore: PatientHealthSyncCursorStore(cursorRepository),
    mapper: const NormalizedHealthEventMapper(),
    committer: committer,
  );
}

class _FakeAdapter implements ingestion.HealthSourceSyncAdapter {
  _FakeAdapter._({required this.initialRecords, required this.changePage});

  factory _FakeAdapter.initial() => _FakeAdapter._(
    initialRecords: [
      ingestion.RawHealthRecord(
        sourcePlatform: ingestion.HealthSourcePlatform.healthConnect,
        sourceType: 'weight',
        sourceRecordId: 'weight-1',
        observedAt: DateTime.utc(2026, 9, 9, 19, 50),
        value: 70,
        unit: 'kg',
        sourceName: 'Health Connect',
      ),
    ],
    changePage: null,
  );

  factory _FakeAdapter.incrementalDelete() => _FakeAdapter._(
    initialRecords: const [],
    changePage: const ingestion.HealthSyncPage(
      changes: [ingestion.HealthSyncChange.delete('weight-1')],
      nextToken: 'token-2',
      hasMore: false,
    ),
  );

  final List<ingestion.RawHealthRecord> initialRecords;
  final ingestion.HealthSyncPage? changePage;

  @override
  ingestion.HealthSourcePlatform get sourcePlatform =>
      ingestion.HealthSourcePlatform.healthConnect;

  @override
  Future<Set<ingestion.HealthDataCategory>> grantedCategories() async => {
    ingestion.HealthDataCategory.body,
  };

  @override
  Future<List<ingestion.RawHealthRecord>> readInitial({
    required DateTime from,
    required DateTime to,
    required Set<ingestion.HealthDataCategory> categories,
  }) async => initialRecords;

  @override
  Future<String> createChangeToken({
    required Set<ingestion.HealthDataCategory> categories,
  }) async => 'token-1';

  @override
  Future<ingestion.HealthSyncPage> readChanges({
    required String token,
    required Set<ingestion.HealthDataCategory> categories,
  }) async =>
      changePage ?? (throw StateError('No incremental page configured.'));
}

class _MemoryCursorRepository implements storage.HealthSyncCursorRepository {
  final Map<String, storage.PersistedHealthSyncCursor> _values = {};

  String _key(String subjectId, storage.HealthSyncCursorSource source) =>
      '$subjectId:${source.name}';

  @override
  Future<void> clear({
    required String subjectId,
    required storage.HealthSyncCursorSource source,
  }) async {
    _values.remove(_key(subjectId, source));
  }

  @override
  Future<storage.PersistedHealthSyncCursor?> load({
    required String subjectId,
    required storage.HealthSyncCursorSource source,
  }) async => _values[_key(subjectId, source)];

  @override
  Future<void> save(storage.PersistedHealthSyncCursor cursor) async {
    _values[_key(cursor.subjectId, cursor.source)] = cursor;
  }
}

class _FakeCommitter implements PatientHealthImportCommitter {
  List<HealthEvent> upserts = const [];
  List<String> deletedEventIds = const [];
  List<storage.AuditEvent> auditEvents = const [];
  storage.PersistedHealthImportHistory? history;
  storage.PersistedHealthSyncCursor? cursor;

  @override
  Future<void> commit({
    required Iterable<HealthEvent> upserts,
    required Iterable<String> deletedEventIds,
    required Iterable<storage.AuditEvent> auditEvents,
    required storage.PersistedHealthImportHistory history,
    required storage.PersistedHealthSyncCursor cursor,
    required DateTime deletedAt,
  }) async {
    this.upserts = List<HealthEvent>.from(upserts);
    this.deletedEventIds = List<String>.from(deletedEventIds);
    this.auditEvents = List<storage.AuditEvent>.from(auditEvents);
    this.history = history;
    this.cursor = cursor;
  }
}
