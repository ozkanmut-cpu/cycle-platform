enum HealthImportSource { healthConnect, healthKit }

class PersistedHealthImportHistory {
  const PersistedHealthImportHistory({
    required this.id,
    required this.subjectId,
    required this.source,
    required this.startedAt,
    required this.finishedAt,
    required this.imported,
    required this.skippedPermission,
    required this.skippedDuplicate,
    required this.unmapped,
    required this.deleted,
    required this.usedFullRefresh,
  });

  final String id;
  final String subjectId;
  final HealthImportSource source;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int imported;
  final int skippedPermission;
  final int skippedDuplicate;
  final int unmapped;
  final int deleted;
  final bool usedFullRefresh;
}

abstract interface class HealthImportHistoryRepository {
  Future<void> append(PersistedHealthImportHistory entry);

  Future<List<PersistedHealthImportHistory>> recent({
    required String subjectId,
    HealthImportSource? source,
    int limit = 50,
  });
}
