enum RelationshipCapability {
  view,
  notify,
  relationshipIntelligence,
  playful,
  intimacy,
}

enum RelationshipVisibility {
  private,
  engineOnly,
  abstractShared,
  fullyShared,
}

enum RelationshipSharingPreset {
  minimal,
  support,
  closePartner,
  fullTransparency,
  custom,
}

class RelationshipPolicyException implements Exception {
  const RelationshipPolicyException(this.message);
  final String message;
  @override
  String toString() => 'RelationshipPolicyException: $message';
}

class RelationshipCategoryGrant {
  RelationshipCategoryGrant({
    required this.id,
    required this.ownerId,
    required this.recipientId,
    required this.category,
    required Set<RelationshipCapability> capabilities,
    required this.visibility,
    required this.createdAt,
    this.validUntil,
    this.revokedAt,
    this.version = 1,
  }) : capabilities = Set.unmodifiable(capabilities) {
    _requireText(id, 'id');
    _requireText(ownerId, 'ownerId');
    _requireText(recipientId, 'recipientId');
    _requireText(category, 'category');
    if (ownerId == recipientId) {
      throw const RelationshipPolicyException(
        'ownerId and recipientId must differ',
      );
    }
    if (version <= 0) {
      throw const RelationshipPolicyException('version must be positive');
    }
    if (validUntil != null && !validUntil!.isAfter(createdAt)) {
      throw const RelationshipPolicyException(
        'validUntil must be after createdAt',
      );
    }
    if (revokedAt != null && revokedAt!.isBefore(createdAt)) {
      throw const RelationshipPolicyException(
        'revokedAt must not precede createdAt',
      );
    }
    _validateVisibility();
  }

  final String id;
  final String ownerId;
  final String recipientId;
  final String category;
  final Set<RelationshipCapability> capabilities;
  final RelationshipVisibility visibility;
  final DateTime createdAt;
  final DateTime? validUntil;
  final DateTime? revokedAt;
  final int version;

  bool isActiveAt(DateTime at) {
    if (at.isBefore(createdAt) || revokedAt != null) return false;
    return validUntil == null || at.isBefore(validUntil!);
  }

  bool allows(RelationshipCapability capability) =>
      capabilities.contains(capability);

  void _validateVisibility() {
    final canView = capabilities.contains(RelationshipCapability.view);
    switch (visibility) {
      case RelationshipVisibility.private:
      case RelationshipVisibility.engineOnly:
        if (canView) {
          throw const RelationshipPolicyException(
            'private and engineOnly grants cannot include view',
          );
        }
      case RelationshipVisibility.abstractShared:
      case RelationshipVisibility.fullyShared:
        if (!canView) {
          throw const RelationshipPolicyException(
            'shared visibility requires view capability',
          );
        }
    }
  }
}

class RelationshipAccessRequest {
  const RelationshipAccessRequest({
    required this.ownerId,
    required this.recipientId,
    required this.category,
    required this.capability,
    required this.at,
  });

  final String ownerId;
  final String recipientId;
  final String category;
  final RelationshipCapability capability;
  final DateTime at;
}

class RelationshipAccessDecision {
  const RelationshipAccessDecision._({
    required this.allowed,
    required this.reason,
    this.matchedGrantId,
    this.visibility,
  });

  const RelationshipAccessDecision.allow({
    required String grantId,
    required RelationshipVisibility visibility,
  }) : this._(
          allowed: true,
          reason: 'allowed',
          matchedGrantId: grantId,
          visibility: visibility,
        );

  const RelationshipAccessDecision.deny(String reason)
      : this._(allowed: false, reason: reason);

  final bool allowed;
  final String reason;
  final String? matchedGrantId;
  final RelationshipVisibility? visibility;
}

class RelationshipPermissionFirewall {
  const RelationshipPermissionFirewall();

  RelationshipAccessDecision evaluate({
    required RelationshipAccessRequest request,
    required Iterable<RelationshipCategoryGrant> grants,
  }) {
    if (_blank(request.ownerId) ||
        _blank(request.recipientId) ||
        _blank(request.category)) {
      return const RelationshipAccessDecision.deny('invalid_scope');
    }
    if (request.ownerId == request.recipientId) {
      return const RelationshipAccessDecision.deny('invalid_recipient');
    }

    final matches = grants
        .where(
          (grant) =>
              grant.ownerId == request.ownerId &&
              grant.recipientId == request.recipientId &&
              grant.category == request.category &&
              grant.isActiveAt(request.at) &&
              grant.allows(request.capability),
        )
        .toList()
      ..sort((a, b) {
        final version = b.version.compareTo(a.version);
        if (version != 0) return version;
        final created = b.createdAt.compareTo(a.createdAt);
        if (created != 0) return created;
        return a.id.compareTo(b.id);
      });

    if (matches.isEmpty) {
      return const RelationshipAccessDecision.deny('no_active_grant');
    }

    final grant = matches.first;
    return RelationshipAccessDecision.allow(
      grantId: grant.id,
      visibility: grant.visibility,
    );
  }
}

class RelationshipContextItem<T> {
  RelationshipContextItem({
    required this.ownerId,
    required this.category,
    required this.value,
    required this.observedAt,
    required this.visibility,
  }) {
    _requireText(ownerId, 'ownerId');
    _requireText(category, 'category');
  }

  final String ownerId;
  final String category;
  final T value;
  final DateTime observedAt;
  final RelationshipVisibility visibility;
}

class RelationshipContextProjection<T> {
  const RelationshipContextProjection({
    required this.ownerId,
    required this.recipientId,
    required this.category,
    required this.capability,
    required this.visibility,
    required this.value,
  });

  final String ownerId;
  final String recipientId;
  final String category;
  final RelationshipCapability capability;
  final RelationshipVisibility visibility;
  final T? value;

  bool get exposesRawValue =>
      visibility == RelationshipVisibility.fullyShared && value != null;
}

class RelationshipContextProjector {
  const RelationshipContextProjector({
    this.firewall = const RelationshipPermissionFirewall(),
  });

  final RelationshipPermissionFirewall firewall;

  RelationshipContextProjection<T>? project<T>({
    required RelationshipContextItem<T> item,
    required String recipientId,
    required RelationshipCapability capability,
    required DateTime at,
    required Iterable<RelationshipCategoryGrant> grants,
  }) {
    final decision = firewall.evaluate(
      request: RelationshipAccessRequest(
        ownerId: item.ownerId,
        recipientId: recipientId,
        category: item.category,
        capability: capability,
        at: at,
      ),
      grants: grants,
    );
    if (!decision.allowed || decision.visibility == null) return null;

    final visibility = _mostRestrictive(item.visibility, decision.visibility!);
    final rawValue =
        visibility == RelationshipVisibility.fullyShared ? item.value : null;
    return RelationshipContextProjection<T>(
      ownerId: item.ownerId,
      recipientId: recipientId,
      category: item.category,
      capability: capability,
      visibility: visibility,
      value: rawValue,
    );
  }
}

RelationshipVisibility _mostRestrictive(
  RelationshipVisibility item,
  RelationshipVisibility grant,
) {
  int rank(RelationshipVisibility value) => switch (value) {
        RelationshipVisibility.private => 0,
        RelationshipVisibility.engineOnly => 1,
        RelationshipVisibility.abstractShared => 2,
        RelationshipVisibility.fullyShared => 3,
      };
  return rank(item) <= rank(grant) ? item : grant;
}

bool _blank(String value) => value.trim().isEmpty;

void _requireText(String value, String field) {
  if (_blank(value))
    throw RelationshipPolicyException('$field must not be blank');
}
