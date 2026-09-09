import 'dart:convert';

import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'sqlcipher_database.dart';

class SqlCipherHealthEventRepository implements HealthEventRepository {
  SqlCipherHealthEventRepository(this._db);

  final SqlCipherDatabase _db;

  @override
  Future<void> upsert(HealthEvent event) async {
    await _db.database.insert('health_events', <String, Object?>{
      'id': event.id,
      'subject_id': event.subjectId,
      'event_type': event.eventType,
      'episode_id': event.episodeId,
      'payload_json': jsonEncode(_encode(event)),
      'observed_at': event.temporal.observedAt.toUtc().toIso8601String(),
      'recorded_at': event.temporal.recordedAt.toUtc().toIso8601String(),
      'schema_version': event.schemaVersion,
      'deleted_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<HealthEvent?> getById(String id) async {
    final rows = await _db.database.query(
      'health_events',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decode(jsonDecode(rows.first['payload_json']! as String));
  }

  @override
  Future<List<HealthEvent>> query({
    required String subjectId,
    String? eventType,
    DateTime? from,
    DateTime? to,
    bool includeSuperseded = false,
  }) async {
    final where = <String>['subject_id = ?', 'deleted_at IS NULL'];
    final args = <Object?>[subjectId];
    if (eventType != null) {
      where.add('event_type = ?');
      args.add(eventType);
    }
    if (from != null) {
      where.add('observed_at >= ?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      where.add('observed_at <= ?');
      args.add(to.toUtc().toIso8601String());
    }

    final rows = await _db.database.query(
      'health_events',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'observed_at DESC',
    );

    final events = rows
        .map((row) => _decode(jsonDecode(row['payload_json']! as String)))
        .toList(growable: false);

    if (includeSuperseded) return events;
    final supersededIds = events
        .map((event) => event.supersedesEventId)
        .whereType<String>()
        .toSet();
    return events.where((event) => !supersededIds.contains(event.id)).toList();
  }

  @override
  Future<void> markDeleted({
    required String eventId,
    required DateTime deletedAt,
  }) async {
    await _db.database.update(
      'health_events',
      <String, Object?>{'deleted_at': deletedAt.toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: <Object?>[eventId],
    );
  }

  Map<String, Object?> _encode(HealthEvent event) {
    return <String, Object?>{
      'id': event.id,
      'subjectId': event.subjectId,
      'eventType': event.eventType,
      'episodeId': event.episodeId,
      'value': event.value,
      'unit': event.unit,
      'severity': event.severity,
      'bodyLocation': event.bodyLocation,
      'dataState': event.dataState?.name,
      'cycleContext': event.cycleContext,
      'pregnancyContext': event.pregnancyContext,
      'provenance': <String, Object?>{
        'sourceKind': event.provenance.sourceKind.name,
        'sourceName': event.provenance.sourceName,
        'sourceRecordId': event.provenance.sourceRecordId,
        'deviceName': event.provenance.deviceName,
        'measurementMethod': event.provenance.measurementMethod,
      },
      'verificationStatus': event.verificationStatus.name,
      'confidence': event.confidence.name,
      'privacyClass': event.privacyClass,
      'visibilityPolicyId': event.visibilityPolicyId,
      'backupPolicyId': event.backupPolicyId,
      'temporal': <String, Object?>{
        'observedAt': event.temporal.observedAt.toUtc().toIso8601String(),
        'recordedAt': event.temporal.recordedAt.toUtc().toIso8601String(),
        'importedAt': event.temporal.importedAt?.toUtc().toIso8601String(),
        'verifiedAt': event.temporal.verifiedAt?.toUtc().toIso8601String(),
        'validFrom': event.temporal.validFrom?.toUtc().toIso8601String(),
        'validTo': event.temporal.validTo?.toUtc().toIso8601String(),
        'knownAt': event.temporal.knownAt?.toUtc().toIso8601String(),
      },
      'supersedesEventId': event.supersedesEventId,
      'relatedEventIds': event.relatedEventIds,
      'schemaVersion': event.schemaVersion,
    };
  }

  HealthEvent _decode(Object? raw) {
    final map = Map<String, Object?>.from(raw! as Map);
    final provenanceMap = Map<String, Object?>.from(map['provenance']! as Map);
    final temporalMap = Map<String, Object?>.from(map['temporal']! as Map);

    T enumByName<T extends Enum>(List<T> values, String name) =>
        values.firstWhere((value) => value.name == name);

    return HealthEvent(
      id: map['id']! as String,
      subjectId: map['subjectId']! as String,
      eventType: map['eventType']! as String,
      episodeId: map['episodeId'] as String?,
      value: map['value'] as num?,
      unit: map['unit'] as String?,
      severity: map['severity'] as int?,
      bodyLocation: map['bodyLocation'] as String?,
      dataState: map['dataState'] == null
          ? null
          : enumByName(DataState.values, map['dataState']! as String),
      cycleContext: map['cycleContext'] == null
          ? null
          : Map<String, Object?>.from(map['cycleContext']! as Map),
      pregnancyContext: map['pregnancyContext'] == null
          ? null
          : Map<String, Object?>.from(map['pregnancyContext']! as Map),
      provenance: Provenance(
        sourceKind: enumByName(
          SourceKind.values,
          provenanceMap['sourceKind']! as String,
        ),
        sourceName: provenanceMap['sourceName'] as String?,
        sourceRecordId: provenanceMap['sourceRecordId'] as String?,
        deviceName: provenanceMap['deviceName'] as String?,
        measurementMethod: provenanceMap['measurementMethod'] as String?,
      ),
      verificationStatus: enumByName(
        VerificationStatus.values,
        map['verificationStatus']! as String,
      ),
      confidence: enumByName(
        ConfidenceClass.values,
        map['confidence']! as String,
      ),
      privacyClass: map['privacyClass']! as String,
      visibilityPolicyId: map['visibilityPolicyId'] as String?,
      backupPolicyId: map['backupPolicyId'] as String?,
      temporal: TemporalMetadata(
        observedAt: DateTime.parse(temporalMap['observedAt']! as String),
        recordedAt: DateTime.parse(temporalMap['recordedAt']! as String),
        importedAt: temporalMap['importedAt'] == null
            ? null
            : DateTime.parse(temporalMap['importedAt']! as String),
        verifiedAt: temporalMap['verifiedAt'] == null
            ? null
            : DateTime.parse(temporalMap['verifiedAt']! as String),
        validFrom: temporalMap['validFrom'] == null
            ? null
            : DateTime.parse(temporalMap['validFrom']! as String),
        validTo: temporalMap['validTo'] == null
            ? null
            : DateTime.parse(temporalMap['validTo']! as String),
        knownAt: temporalMap['knownAt'] == null
            ? null
            : DateTime.parse(temporalMap['knownAt']! as String),
      ),
      supersedesEventId: map['supersedesEventId'] as String?,
      relatedEventIds:
          (map['relatedEventIds'] as List<Object?>? ?? const <Object?>[])
              .cast<String>(),
      schemaVersion: map['schemaVersion']! as int,
    );
  }
}
