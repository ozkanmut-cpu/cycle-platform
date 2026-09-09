import 'package:cycle_health_ingestion/cycle_health_ingestion.dart'
    as ingestion;
import 'package:cycle_storage/cycle_storage.dart' as storage;
import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_patient/health/health_sync_cursor_store.dart';

void main() {
  test('round trips a Health Connect cursor', () async {
    final repository = _MemoryCursorRepository();
    final store = PatientHealthSyncCursorStore(repository);
    final updatedAt = DateTime.utc(2026, 9, 9, 19, 0);

    await store.save(
      subjectId: 'local-user',
      cursor: ingestion.HealthSyncCursor(
        sourcePlatform: ingestion.HealthSourcePlatform.healthConnect,
        token: 'hc-token-1',
        updatedAt: updatedAt,
      ),
    );

    final loaded = await store.load(
      subjectId: 'local-user',
      sourcePlatform: ingestion.HealthSourcePlatform.healthConnect,
    );

    expect(loaded, isNotNull);
    expect(loaded!.token, 'hc-token-1');
    expect(loaded.sourcePlatform, ingestion.HealthSourcePlatform.healthConnect);
    expect(loaded.updatedAt, updatedAt);
  });

  test('keeps HealthKit and Health Connect cursors isolated', () async {
    final repository = _MemoryCursorRepository();
    final store = PatientHealthSyncCursorStore(repository);

    await store.save(
      subjectId: 'local-user',
      cursor: ingestion.HealthSyncCursor(
        sourcePlatform: ingestion.HealthSourcePlatform.healthKit,
        token: 'hk-anchor-1',
        updatedAt: DateTime.utc(2026, 9, 9, 19, 1),
      ),
    );

    expect(
      await store.load(
        subjectId: 'local-user',
        sourcePlatform: ingestion.HealthSourcePlatform.healthConnect,
      ),
      isNull,
    );
    expect(
      (await store.load(
        subjectId: 'local-user',
        sourcePlatform: ingestion.HealthSourcePlatform.healthKit,
      ))?.token,
      'hk-anchor-1',
    );
  });
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
