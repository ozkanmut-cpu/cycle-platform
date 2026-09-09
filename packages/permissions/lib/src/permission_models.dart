enum PermissionAction {
  view,
  notify,
  backup,
  export,
}

enum RecipientKind {
  partner,
  clinician,
  caregiver,
  trustedPerson,
  unknown,
}

class PermissionScope {
  const PermissionScope({
    this.categories = const <String>{},
    this.fields = const <String>{},
    this.purposes = const <String>{},
    this.validFrom,
    this.validUntil,
  });

  final Set<String> categories;
  final Set<String> fields;
  final Set<String> purposes;
  final DateTime? validFrom;
  final DateTime? validUntil;

  bool isActiveAt(DateTime at) {
    if (validFrom != null && at.isBefore(validFrom!)) return false;
    if (validUntil != null && !at.isBefore(validUntil!)) return false;
    return true;
  }
}

class PermissionGrant {
  const PermissionGrant({
    required this.id,
    required this.ownerId,
    required this.recipientId,
    required this.recipientKind,
    required this.actions,
    required this.scope,
    required this.createdAt,
    this.revokedAt,
    this.version = 1,
  });

  final String id;
  final String ownerId;
  final String recipientId;
  final RecipientKind recipientKind;
  final Set<PermissionAction> actions;
  final PermissionScope scope;
  final DateTime createdAt;
  final DateTime? revokedAt;
  final int version;

  bool get isRevoked => revokedAt != null;
}

class PermissionRequest {
  const PermissionRequest({
    required this.ownerId,
    required this.recipientId,
    required this.action,
    required this.category,
    required this.at,
    this.field,
    this.purpose,
  });

  final String ownerId;
  final String recipientId;
  final PermissionAction action;
  final String category;
  final String? field;
  final String? purpose;
  final DateTime at;
}

class PermissionDecision {
  const PermissionDecision._({
    required this.allowed,
    required this.reason,
    this.matchedGrantId,
  });

  const PermissionDecision.allow(String grantId)
      : this._(
          allowed: true,
          reason: 'allowed',
          matchedGrantId: grantId,
        );

  const PermissionDecision.deny(String reason)
      : this._(
          allowed: false,
          reason: reason,
        );

  final bool allowed;
  final String reason;
  final String? matchedGrantId;
}

class PermissionRevocationEffect {
  const PermissionRevocationEffect({
    required this.grantId,
    required this.rotateRecipientKeys,
    required this.stopNotifications,
    required this.invalidateExports,
  });

  final String grantId;
  final bool rotateRecipientKeys;
  final bool stopNotifications;
  final bool invalidateExports;
}
