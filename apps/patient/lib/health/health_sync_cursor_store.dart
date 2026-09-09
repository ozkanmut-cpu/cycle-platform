import 'package:cycle_health_ingestion/cycle_health_ingestion.dart' as ingestion;
import 'package:cycle_storage/cycle_storage.dart' as storage;

class PatientHealthSyncCursorStore {
  const PatientHealthSyncCursorStore(this.repository);

  final storage.HealthSyncCursorRepository repository;

  Future<ingestion.HealthSyncCursor?> load({
    required String subjectId,
    required ingestion.HealthSourcePlatform sourcePlatform,
  }) async {
    final persisted = await repository.load(
      subjectId: subjectId,
      source: _toStorageSource(sourcePlatform),
    );
    if (persisted == null) return null;

    return ingestion.HealthSyncCursor(
      sourcePlatform: sourcePlatform,
      token: persisted.value,
      updatedAt: persisted.updatedAt,
    );
  }

  Future<void> save({
    required String subjectId,
    required ingestion.HealthSyncCursor cursor,
  }) => repository.save(
    storage.PersistedHealthSyncCursor(
      subjectId: subjectId,
      source: _toStorageSource(cursor.sourcePlatform),
      value: cursor.token,
      updatedAt: cursor.updatedAt,
    ),
  );

  Future<void> clear({
    required String subjectId,
    required ingestion.HealthSourcePlatform sourcePlatform,
  }) => repository.clear(
    subjectId: subjectId,
    source: _toStorageSource(sourcePlatform),
  );
}

storage.HealthSyncCursorSource _toStorageSource(
  ingestion.HealthSourcePlatform sourcePlatform,
) => switch (sourcePlatform) {
  ingestion.HealthSourcePlatform.healthConnect =>
    storage.HealthSyncCursorSource.healthConnect,
  ingestion.HealthSourcePlatform.healthKit =>
    storage.HealthSyncCursorSource.healthKit,
};
