import 'relationship_policy.dart';

enum RelationshipSignalOrigin { explicit, derived }

enum RelationshipSignalLifecycle { active, expired, superseded, revoked }

enum RelationshipSignalKind {
  love,
  touch,
  listen,
  presence,
  practicalHelp,
  fun,
  space,
  talk,
  flirt,
  intimacy,
  surprise,
  custom,
}

class RelationshipSignal {
  RelationshipSignal({
    required this.id,
    required this.ownerId,
    required this.recipientId,
    required this.kind,
    required this.origin,
    required this.createdAt,
    this.expiresAt,
    this.revokedAt,
    this.customKey,
    this.partnerFacingText,
    this.version = 1,
  }) {
    _requireSignalText(id, 'id');
    _requireSignalText(ownerId, 'ownerId');
    _requireSignalText(recipientId, 'recipientId');
    if (ownerId == recipientId) {
      throw const RelationshipPolicyException(
          'signal owner and recipient must differ');
    }
    if (version <= 0) {
      throw const RelationshipPolicyException(
          'signal version must be positive');
    }
    if (expiresAt != null && !expiresAt!.isAfter(createdAt)) {
      throw const RelationshipPolicyException(
          'signal expiresAt must be after createdAt');
    }
    if (revokedAt != null && revokedAt!.isBefore(createdAt)) {
      throw const RelationshipPolicyException(
          'signal revokedAt must not precede createdAt');
    }
    if (kind == RelationshipSignalKind.custom) {
      _requireSignalText(customKey ?? '', 'customKey');
    }
  }

  final String id;
  final String ownerId;
  final String recipientId;
  final RelationshipSignalKind kind;
  final RelationshipSignalOrigin origin;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final String? customKey;
  final String? partnerFacingText;
  final int version;

  bool isActiveAt(DateTime at) {
    if (at.isBefore(createdAt)) return false;
    if (revokedAt != null && !at.isBefore(revokedAt!)) return false;
    if (expiresAt != null && !at.isBefore(expiresAt!)) return false;
    return true;
  }

  String get logicalDomain => kind == RelationshipSignalKind.custom
      ? 'custom:${customKey!.trim()}'
      : kind.name;
}

class PartnerSignal {
  const PartnerSignal({
    required this.id,
    required this.ownerId,
    required this.recipientId,
    required this.kind,
    required this.origin,
    required this.createdAt,
    required this.expiresAt,
    required this.visibility,
    required this.lifecycle,
    this.partnerFacingText,
  });

  final String id;
  final String ownerId;
  final String recipientId;
  final RelationshipSignalKind kind;
  final RelationshipSignalOrigin origin;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final RelationshipVisibility visibility;
  final RelationshipSignalLifecycle lifecycle;
  final String? partnerFacingText;
}

class RelationshipSignalEngine {
  const RelationshipSignalEngine();

  List<RelationshipSignal> selectActive({
    required String ownerId,
    required String recipientId,
    required DateTime at,
    required Iterable<RelationshipSignal> signals,
  }) {
    final scoped = signals
        .where((signal) =>
            signal.ownerId == ownerId &&
            signal.recipientId == recipientId &&
            signal.isActiveAt(at))
        .toList();

    final byDomain = <String, List<RelationshipSignal>>{};
    for (final signal in scoped) {
      byDomain.putIfAbsent(signal.logicalDomain, () => []).add(signal);
    }

    final selected = <RelationshipSignal>[];
    final domains = byDomain.keys.toList()..sort();
    for (final domain in domains) {
      final candidates = byDomain[domain]!;
      candidates.sort((a, b) {
        final explicitOrder =
            _originRank(b.origin).compareTo(_originRank(a.origin));
        if (explicitOrder != 0) return explicitOrder;
        final versionOrder = b.version.compareTo(a.version);
        if (versionOrder != 0) return versionOrder;
        final createdOrder = b.createdAt.compareTo(a.createdAt);
        if (createdOrder != 0) return createdOrder;
        return a.id.compareTo(b.id);
      });
      selected.add(candidates.first);
    }
    return List.unmodifiable(selected);
  }
}

class PartnerSignalProjector {
  const PartnerSignalProjector({
    this.firewall = const RelationshipPermissionFirewall(),
  });

  final RelationshipPermissionFirewall firewall;

  List<PartnerSignal> project({
    required String ownerId,
    required String recipientId,
    required DateTime at,
    required Iterable<RelationshipSignal> signals,
    required Iterable<RelationshipCategoryGrant> grants,
  }) {
    final selected = const RelationshipSignalEngine().selectActive(
      ownerId: ownerId,
      recipientId: recipientId,
      at: at,
      signals: signals,
    );
    final result = <PartnerSignal>[];
    for (final signal in selected) {
      final category = 'relationship.signal.${signal.logicalDomain}';
      final decision = firewall.evaluate(
        request: RelationshipAccessRequest(
          ownerId: ownerId,
          recipientId: recipientId,
          category: category,
          capability: RelationshipCapability.view,
          at: at,
        ),
        grants: grants,
      );
      if (!decision.allowed || decision.visibility == null) continue;
      result.add(
        PartnerSignal(
          id: signal.id,
          ownerId: ownerId,
          recipientId: recipientId,
          kind: signal.kind,
          origin: signal.origin,
          createdAt: signal.createdAt,
          expiresAt: signal.expiresAt,
          visibility: decision.visibility!,
          lifecycle: RelationshipSignalLifecycle.active,
          partnerFacingText: signal.partnerFacingText,
        ),
      );
    }
    result.sort((a, b) {
      final kind = a.kind.name.compareTo(b.kind.name);
      if (kind != 0) return kind;
      return a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }
}

int _originRank(RelationshipSignalOrigin origin) =>
    origin == RelationshipSignalOrigin.explicit ? 1 : 0;

void _requireSignalText(String value, String field) {
  if (value.trim().isEmpty) {
    throw RelationshipPolicyException('$field must not be blank');
  }
}
