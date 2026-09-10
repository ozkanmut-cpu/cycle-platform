import 'package:cycle_storage/cycle_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'sqlcipher_database.dart';

class SqlCipherHealthImportHistoryRepository
    implements HealthImportHistoryRepository {
  SqlCipherHealthImportHistoryRepository(this._db);

  final SqlCipherDatabase _db;

  @override
  Future<void> append(PersistedHealthImportHistory entry) =>
      appendWithExecutor(_db.database, entry);

  Future<void> appendWithExecutor(
    DatabaseExecutor executor,
    PersistedHealthImportHistory entry,
  ) async {
    await executor.insert('health_import_history', <String, Object?>{
      'id': entry.id,
      'subject_id': entry.subjectId,
      'source': entry.source.name,
      'started_at': entry.startedAt.toUtc().toIso8601String(),
      'finished_at': entry.finishedAt.toUtc().toIso8601String(),
      'imported': entry.imported,
      'skipped_permission': entry.skippedPermission,
      'skipped_duplicate': entry.skippedDuplicate,
      'unmapped': entry.unmapped,
      'deleted': entry.deleted,
      'used_full_refresh': entry.usedFullRefresh ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  @override
  Future<List<PersistedHealthImportHistory>> recent({
    required String subjectId,
    HealthImportSource? source,
    int limit = 50,
  }) async {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }

    final where = <String>['subject_id = ?'];
    final args = <Object?>[subjectId];
    if (source != null) {
      where.add('source = ?');
      args.add(source.name);
    }

    final rows = await _db.database.query(
      'health_import_history',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'finished_at DESC',
      limit: limit,
    );
    return rows.map(_decode).toList(growable: false);
  }

  PersistedHealthImportHistory _decode(Map<String, Object?> row) {
    return PersistedHealthImportHistory(
      id: row['id']! as String,
      subjectId: row['subject_id']! as String,
      source: HealthImportSource.values.firstWhere(
        (candidate) => candidate.name == row['source']! as String,
      ),
      startedAt: DateTime.parse(row['started_at']! as String),
      finishedAt: DateTime.parse(row['finished_at']! as String),
      imported: row['imported']! as int,
      skippedPermission: row['skipped_permission']! as int,
      skippedDuplicate: row['skipped_duplicate']! as int,
      unmapped: row['unmapped']! as int,
      deleted: row['deleted']! as int,
      usedFullRefresh: (row['used_full_refresh']! as int) != 0,
    );
  }
}
