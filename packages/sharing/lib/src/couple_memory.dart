import 'relationship_policy.dart';

enum CoupleMemoryKind {
  nickname,
  importantDate,
  sharedMemory,
  favorite,
  supportPreference,
  boundary,
  dontSuggest,
  partnerManual,
  custom,
}

class CoupleMemoryItem {
  CoupleMemoryItem({
    required this.id,
    required this.ownerId,
    required this.partnerId,
    required this.kind,
    required this.key,
    required this.value,
    required this.createdAt,
    required this.visibility,
    this.validUntil,
    this.revokedAt,
    this.version = 1,
  }) {
    _requireMemoryText(id, 'id');
    _requireMemoryText(ownerId, 'ownerId');
    _requireMemoryText(partnerId, 'partnerId');
    _requireMemoryText(key, 'key');
    _requireMemoryText(value, 'value');
    if (ownerId == partnerId) {
      throw const RelationshipPolicyException(
        'couple memory owner and partner must differ',
      );
    }
    if (version <= 0) {
      throw const RelationshipPolicyException(
          'memory version must be positive');
    }
    if (validUntil != null && !validUntil!.isAfter(createdAt)) {
      throw const RelationshipPolicyException(
        'memory validUntil must be after createdAt',
      );
    }
    if (revokedAt != null && revokedAt!.isBefore(createdAt)) {
      throw const RelationshipPolicyException(
        'memory revokedAt must not precede createdAt',
      );
    }
  }

  final String id;
  final String ownerId;
  final String partnerId;
  final CoupleMemoryKind kind;
  final String key;
  final String value;
  final DateTime createdAt;
  final RelationshipVisibility visibility;
  final DateTime? validUntil;
  final DateTime? revokedAt;
  final int version;

  bool isActiveAt(DateTime at) {
    if (at.isBefore(createdAt) || revokedAt != null) return false;
    return validUntil == null || at.isBefore(validUntil!);
  }

  String get category => 'relationship.memory.${kind.name}.$key';
  String get logicalKey => '${kind.name}|$key';
}

class CoupleMemoryProjection {
  const CoupleMemoryProjection({
    required this.id,
    required this.ownerId,
    required this.recipientId,
    required this.kind,
    required this.key,
    required this.capability,
    required this.visibility,
    required this.value,
  });

  final String id;
  final String ownerId;
  final String recipientId;
  final CoupleMemoryKind kind;
  final String key;
  final RelationshipCapability capability;
  final RelationshipVisibility visibility;
  final String? value;

  bool get exposesRawValue =>
      visibility == RelationshipVisibility.fullyShared && value != null;
}

class PartnerManual {
  PartnerManual({
    required this.ownerId,
    required this.partnerId,
    required Iterable<CoupleMemoryProjection> entries,
  }) : entries = List.unmodifiable(entries);

  final String ownerId;
  final String partnerId;
  final List<CoupleMemoryProjection> entries;
}

class CoupleMemoryEngine {
  const CoupleMemoryEngine({
    this.firewall = const RelationshipPermissionFirewall(),
  });

  final RelationshipPermissionFirewall firewall;

  PartnerManual buildPartnerManual({
    required String ownerId,
    required String partnerId,
    required RelationshipCapability capability,
    required DateTime at,
    required Iterable<CoupleMemoryItem> items,
    required Iterable<RelationshipCategoryGrant> grants,
  }) {
    if (ownerId.trim().isEmpty ||
        partnerId.trim().isEmpty ||
        ownerId == partnerId) {
      throw const RelationshipPolicyException('invalid couple memory scope');
    }

    final scoped = items
        .where((item) =>
            item.ownerId == ownerId &&
            item.partnerId == partnerId &&
            item.isActiveAt(at))
        .toList()
      ..sort((a, b) {
        final logical = a.logicalKey.compareTo(b.logicalKey);
        if (logical != 0) return logical;
        final version = b.version.compareTo(a.version);
        if (version != 0) return version;
        final created = b.createdAt.compareTo(a.createdAt);
        if (created != 0) return created;
        return a.id.compareTo(b.id);
      });

    final seen = <String>{};
    final projections = <CoupleMemoryProjection>[];
    for (final item in scoped) {
      if (!seen.add(item.logicalKey)) continue;
      final decision = firewall.evaluate(
        request: RelationshipAccessRequest(
          ownerId: ownerId,
          recipientId: partnerId,
          category: item.category,
          capability: capability,
          at: at,
        ),
        grants: grants,
      );
      if (!decision.allowed || decision.visibility == null) continue;
      final visibility = _restrictMemoryVisibility(
        item.visibility,
        decision.visibility!,
      );
      final raw =
          visibility == RelationshipVisibility.fullyShared ? item.value : null;
      projections.add(
        CoupleMemoryProjection(
          id: item.id,
          ownerId: ownerId,
          recipientId: partnerId,
          kind: item.kind,
          key: item.key,
          capability: capability,
          visibility: visibility,
          value: raw,
        ),
      );
    }

    projections.sort((a, b) {
      final kind = a.kind.name.compareTo(b.kind.name);
      if (kind != 0) return kind;
      final key = a.key.compareTo(b.key);
      if (key != 0) return key;
      return a.id.compareTo(b.id);
    });

    return PartnerManual(
      ownerId: ownerId,
      partnerId: partnerId,
      entries: projections,
    );
  }
}

RelationshipVisibility _restrictMemoryVisibility(
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

void _requireMemoryText(String value, String field) {
  if (value.trim().isEmpty) {
    throw RelationshipPolicyException('$field must not be blank');
  }
}
