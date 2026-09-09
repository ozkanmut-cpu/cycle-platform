enum HealthSyncCursorSource {
  healthConnect,
  healthKit,
}

class PersistedHealthSyncCursor {
  const PersistedHealthSyncCursor({
    required this.subjectId,
    required this.source,
    required this.value,
    required this.updatedAt,
  });

  final String subjectId;
  final HealthSyncCursorSource source;
  final String value;
  final DateTime updatedAt;
}

abstract interface class HealthSyncCursorRepository {
  Future<PersistedHealthSyncCursor?> load({
    required String subjectId,
    required HealthSyncCursorSource source,
  });

  Future<void> save(PersistedHealthSyncCursor cursor);

  Future<void> clear({
    required String subjectId,
    required HealthSyncCursorSource source,
  });
}
