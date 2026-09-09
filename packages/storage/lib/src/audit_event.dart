enum AuditAction {
  created,
  updated,
  deleted,
  imported,
  aiExtracted,
  userConfirmed,
  clinicianVerified,
  shared,
  permissionChanged,
  revoked,
  exported,
  backupCreated,
  restored,
  cryptographicErase,
}

class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.action,
    required this.occurredAt,
    required this.actorId,
    required this.subjectType,
    required this.subjectId,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final AuditAction action;
  final DateTime occurredAt;
  final String actorId;
  final String subjectType;
  final String subjectId;
  final Map<String, Object?> metadata;
}

abstract interface class AuditLogRepository {
  Future<void> append(AuditEvent event);

  Future<List<AuditEvent>> listForSubject(
    String subjectId, {
    int limit = 200,
  });
}
