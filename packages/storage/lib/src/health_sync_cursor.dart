enum HealthSyncCursorSource {
  healthConnect,
  healthKit,
}

class HealthSyncCursor {
  const HealthSyncCursor({
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
  Future<HealthSyncCursor?> load({
    required String subjectId,
    required HealthSyncCursorSource source,
  });

  Future<void> save(HealthSyncCursor cursor);

  Future<void> clear({
    required String subjectId,
    required HealthSyncCursorSource source,
  });
}
