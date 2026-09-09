import 'dart:convert';

import 'package:cycle_storage/cycle_storage.dart';

import 'sqlcipher_database.dart';

class SqlCipherAuditLogRepository implements AuditLogRepository {
  SqlCipherAuditLogRepository(this._db);

  final SqlCipherDatabase _db;

  @override
  Future<void> append(AuditEvent event) async {
    await _db.database.insert(
      'audit_events',
      <String, Object?>{
        'id': event.id,
        'action': event.action.name,
        'subject_id': event.subjectId,
        'subject_type': event.subjectType,
        'actor_id': event.actorId,
        'metadata_json': jsonEncode(event.metadata),
        'occurred_at': event.occurredAt.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<List<AuditEvent>> listForSubject(
    String subjectId, {
    int limit = 200,
  }) async {
    final rows = await _db.database.query(
      'audit_events',
      where: 'subject_id = ?',
      whereArgs: <Object?>[subjectId],
      orderBy: 'occurred_at DESC',
      limit: limit,
    );

    return rows.map((row) {
      final metadataRaw = row['metadata_json'] as String?;
      final metadata = metadataRaw == null || metadataRaw.isEmpty
          ? const <String, Object?>{}
          : Map<String, Object?>.from(jsonDecode(metadataRaw) as Map);

      return AuditEvent(
        id: row['id']! as String,
        action: AuditAction.values.firstWhere(
          (action) => action.name == row['action']! as String,
        ),
        occurredAt: DateTime.parse(row['occurred_at']! as String),
        actorId: row['actor_id']! as String,
        subjectType: row['subject_type']! as String,
        subjectId: row['subject_id']! as String,
        metadata: metadata,
      );
    }).toList(growable: false);
  }
}
