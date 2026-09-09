import 'package:cycle_storage/cycle_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'sqlcipher_database.dart';

class SqlCipherHealthSyncCursorRepository
    implements HealthSyncCursorRepository {
  SqlCipherHealthSyncCursorRepository(this._db);

  final SqlCipherDatabase _db;

  @override
  Future<HealthSyncCursor?> load({
    required String subjectId,
    required HealthSyncCursorSource source,
  }) async {
    final rows = await _db.database.query(
      'health_sync_cursors',
      where: 'subject_id = ? AND source = ?',
      whereArgs: <Object?>[subjectId, source.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.single;
    return HealthSyncCursor(
      subjectId: row['subject_id']! as String,
      source: HealthSyncCursorSource.values.firstWhere(
        (candidate) => candidate.name == row['source']! as String,
      ),
      value: row['cursor_value']! as String,
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }

  @override
  Future<void> save(HealthSyncCursor cursor) async {
    if (cursor.subjectId.isEmpty) {
      throw ArgumentError.value(cursor.subjectId, 'subjectId', 'must not be empty');
    }
    if (cursor.value.isEmpty) {
      throw ArgumentError.value(cursor.value, 'value', 'must not be empty');
    }

    await _db.database.insert(
      'health_sync_cursors',
      <String, Object?>{
        'subject_id': cursor.subjectId,
        'source': cursor.source.name,
        'cursor_value': cursor.value,
        'updated_at': cursor.updatedAt.toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clear({
    required String subjectId,
    required HealthSyncCursorSource source,
  }) async {
    await _db.database.delete(
      'health_sync_cursors',
      where: 'subject_id = ? AND source = ?',
      whereArgs: <Object?>[subjectId, source.name],
    );
  }
}
