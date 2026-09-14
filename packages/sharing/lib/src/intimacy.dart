import 'relationship_policy.dart';

enum IntimacyPreferenceLevel {
  love,
  interested,
  curious,
  maybe,
  askMe,
  notInterested,
}

enum CurrentWillingness {
  no,
  notTonight,
  askFirst,
  maybe,
  yes,
}

enum IntimacyDecisionKind {
  blocked,
  askFirst,
  mutuallyWilling,
}

class IntimacyPreference {
  IntimacyPreference({
    required this.id,
    required this.ownerId,
    required this.partnerId,
    required this.category,
    required this.optionKey,
    required this.level,
    required this.createdAt,
    this.revokedAt,
    this.version = 1,
  }) {
    _requireIntimacyText(id, 'id');
    _requireIntimacyText(ownerId, 'ownerId');
    _requireIntimacyText(partnerId, 'partnerId');
    _requireIntimacyText(category, 'category');
    _requireIntimacyText(optionKey, 'optionKey');
    if (ownerId == partnerId) {
      throw const RelationshipPolicyException(
        'intimacy preference owner and partner must differ',
      );
    }
    if (version <= 0) {
      throw const RelationshipPolicyException(
        'intimacy preference version must be positive',
      );
    }
    if (revokedAt != null && revokedAt!.isBefore(createdAt)) {
      throw const RelationshipPolicyException(
        'intimacy preference revokedAt must not precede createdAt',
      );
    }
  }

  final String id;
  final String ownerId;
  final String partnerId;
  final String category;
  final String optionKey;
  final IntimacyPreferenceLevel level;
  final DateTime createdAt;
  final DateTime? revokedAt;
  final int version;

  bool isActiveAt(DateTime at) => !at.isBefore(createdAt) && revokedAt == null;

  bool get mayMatch => level != IntimacyPreferenceLevel.notInterested;
}

class IntimacyWillingness {
  IntimacyWillingness({
    required this.id,
    required this.ownerId,
    required this.partnerId,
    required this.category,
    required this.optionKey,
    required this.willingness,
    required this.createdAt,
    required this.expiresAt,
    this.revokedAt,
    this.cooldownUntil,
    this.version = 1,
  }) {
    _requireIntimacyText(id, 'id');
    _requireIntimacyText(ownerId, 'ownerId');
    _requireIntimacyText(partnerId, 'partnerId');
    _requireIntimacyText(category, 'category');
    _requireIntimacyText(optionKey, 'optionKey');
    if (ownerId == partnerId) {
      throw const RelationshipPolicyException(
        'intimacy willingness owner and partner must differ',
      );
    }
    if (!expiresAt.isAfter(createdAt)) {
      throw const RelationshipPolicyException(
        'current willingness must be time-limited',
      );
    }
    if (revokedAt != null && revokedAt!.isBefore(createdAt)) {
      throw const RelationshipPolicyException(
        'willingness revokedAt must not precede createdAt',
      );
    }
    if (cooldownUntil != null && cooldownUntil!.isBefore(createdAt)) {
      throw const RelationshipPolicyException(
        'cooldownUntil must not precede createdAt',
      );
    }
    if (version <= 0) {
      throw const RelationshipPolicyException(
        'willingness version must be positive',
      );
    }
  }

  final String id;
  final String ownerId;
  final String partnerId;
  final String category;
  final String optionKey;
  final CurrentWillingness willingness;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final DateTime? cooldownUntil;
  final int version;

  bool isActiveAt(DateTime at) {
    if (at.isBefore(createdAt) || revokedAt != null) return false;
    return at.isBefore(expiresAt);
  }

  bool isCoolingDownAt(DateTime at) =>
      cooldownUntil != null && at.isBefore(cooldownUntil!);
}

class IntimacyBoundary {
  IntimacyBoundary({
    required this.id,
    required this.ownerId,
    required this.partnerId,
    required this.category,
    required this.createdAt,
    this.optionKey,
    this.blocked = false,
    this.askFirst = false,
    this.revokedAt,
  }) {
    _requireIntimacyText(id, 'id');
    _requireIntimacyText(ownerId, 'ownerId');
    _requireIntimacyText(partnerId, 'partnerId');
    _requireIntimacyText(category, 'category');
    if (ownerId == partnerId) {
      throw const RelationshipPolicyException(
        'intimacy boundary owner and partner must differ',
      );
    }
  }

  final String id;
  final String ownerId;
  final String partnerId;
  final String category;
  final String? optionKey;
  final bool blocked;
  final bool askFirst;
  final DateTime createdAt;
  final DateTime? revokedAt;

  bool appliesTo(String category, String optionKey, DateTime at) =>
      !at.isBefore(createdAt) &&
      revokedAt == null &&
      this.category == category &&
      (this.optionKey == null || this.optionKey == optionKey);
}

class IntimacyDecision {
  const IntimacyDecision({
    required this.id,
    required this.participantAId,
    required this.participantBId,
    required this.category,
    required this.optionKey,
    required this.kind,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String participantAId;
  final String participantBId;
  final String category;
  final String optionKey;
  final IntimacyDecisionKind kind;
  final DateTime createdAt;
  final DateTime expiresAt;
}

class IntimacyEngine {
  const IntimacyEngine({
    this.firewall = const RelationshipPermissionFirewall(),
  });

  final RelationshipPermissionFirewall firewall;

  List<IntimacyDecision> evaluate({
    required String participantAId,
    required String participantBId,
    required DateTime at,
    required Iterable<IntimacyPreference> preferences,
    required Iterable<IntimacyWillingness> willingness,
    required Iterable<IntimacyBoundary> boundaries,
    required Iterable<RelationshipCategoryGrant> grants,
  }) {
    _requireIntimacyText(participantAId, 'participantAId');
    _requireIntimacyText(participantBId, 'participantBId');
    if (participantAId == participantBId) {
      throw const RelationshipPolicyException(
        'intimacy participants must differ',
      );
    }

    final prefs = preferences.where((p) {
      final correctPair =
          (p.ownerId == participantAId && p.partnerId == participantBId) ||
              (p.ownerId == participantBId && p.partnerId == participantAId);
      return correctPair && p.isActiveAt(at) && p.mayMatch;
    }).toList();

    final keys = prefs
        .map((p) => '${p.category}\u0000${p.optionKey}')
        .toSet()
        .toList()
      ..sort();
    final decisions = <IntimacyDecision>[];

    for (final key in keys) {
      final parts = key.split('\u0000');
      final category = parts[0];
      final optionKey = parts[1];
      final aPref = _latestPreference(
        prefs,
        ownerId: participantAId,
        partnerId: participantBId,
        category: category,
        optionKey: optionKey,
      );
      final bPref = _latestPreference(
        prefs,
        ownerId: participantBId,
        partnerId: participantAId,
        category: category,
        optionKey: optionKey,
      );
      if (aPref == null || bPref == null) continue;

      final permissionCategory = 'relationship.intimacy.$category';
      if (!_intimacyAllowed(
            ownerId: participantAId,
            recipientId: participantBId,
            category: permissionCategory,
            at: at,
            grants: grants,
          ) ||
          !_intimacyAllowed(
            ownerId: participantBId,
            recipientId: participantAId,
            category: permissionCategory,
            at: at,
            grants: grants,
          )) {
        continue;
      }

      final aNow = _latestWillingness(
        willingness,
        ownerId: participantAId,
        partnerId: participantBId,
        category: category,
        optionKey: optionKey,
        at: at,
      );
      final bNow = _latestWillingness(
        willingness,
        ownerId: participantBId,
        partnerId: participantAId,
        category: category,
        optionKey: optionKey,
        at: at,
      );
      if (aNow == null || bNow == null) continue;

      final aBoundary = _effectiveBoundary(
        boundaries,
        ownerId: participantAId,
        partnerId: participantBId,
        category: category,
        optionKey: optionKey,
        at: at,
      );
      final bBoundary = _effectiveBoundary(
        boundaries,
        ownerId: participantBId,
        partnerId: participantAId,
        category: category,
        optionKey: optionKey,
        at: at,
      );

      final kind = _decisionKind(aNow, bNow, aBoundary, bBoundary, at);
      if (kind == IntimacyDecisionKind.blocked) continue;

      final participants = [participantAId, participantBId]..sort();
      final expiresAt = aNow.expiresAt.isBefore(bNow.expiresAt)
          ? aNow.expiresAt
          : bNow.expiresAt;
      decisions.add(
        IntimacyDecision(
          id: 'intimacy-${participants[0]}-${participants[1]}-$category-$optionKey-${kind.name}',
          participantAId: participants[0],
          participantBId: participants[1],
          category: category,
          optionKey: optionKey,
          kind: kind,
          createdAt: aNow.createdAt.isAfter(bNow.createdAt)
              ? aNow.createdAt
              : bNow.createdAt,
          expiresAt: expiresAt,
        ),
      );
    }

    decisions.sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(decisions);
  }

  IntimacyPreference? _latestPreference(
    Iterable<IntimacyPreference> values, {
    required String ownerId,
    required String partnerId,
    required String category,
    required String optionKey,
  }) {
    final matching = values
        .where((p) =>
            p.ownerId == ownerId &&
            p.partnerId == partnerId &&
            p.category == category &&
            p.optionKey == optionKey)
        .toList()
      ..sort((a, b) {
        final version = b.version.compareTo(a.version);
        if (version != 0) return version;
        final created = b.createdAt.compareTo(a.createdAt);
        if (created != 0) return created;
        return a.id.compareTo(b.id);
      });
    return matching.isEmpty ? null : matching.first;
  }

  IntimacyWillingness? _latestWillingness(
    Iterable<IntimacyWillingness> values, {
    required String ownerId,
    required String partnerId,
    required String category,
    required String optionKey,
    required DateTime at,
  }) {
    final matching = values
        .where((w) =>
            w.ownerId == ownerId &&
            w.partnerId == partnerId &&
            w.category == category &&
            w.optionKey == optionKey &&
            w.isActiveAt(at))
        .toList()
      ..sort((a, b) {
        final version = b.version.compareTo(a.version);
        if (version != 0) return version;
        final created = b.createdAt.compareTo(a.createdAt);
        if (created != 0) return created;
        return a.id.compareTo(b.id);
      });
    return matching.isEmpty ? null : matching.first;
  }

  IntimacyBoundary? _effectiveBoundary(
    Iterable<IntimacyBoundary> values, {
    required String ownerId,
    required String partnerId,
    required String category,
    required String optionKey,
    required DateTime at,
  }) {
    final matching = values
        .where((b) =>
            b.ownerId == ownerId &&
            b.partnerId == partnerId &&
            b.appliesTo(category, optionKey, at))
        .toList()
      ..sort((a, b) {
        if (a.blocked != b.blocked) return a.blocked ? -1 : 1;
        if (a.askFirst != b.askFirst) return a.askFirst ? -1 : 1;
        final created = b.createdAt.compareTo(a.createdAt);
        if (created != 0) return created;
        return a.id.compareTo(b.id);
      });
    return matching.isEmpty ? null : matching.first;
  }

  IntimacyDecisionKind _decisionKind(
    IntimacyWillingness a,
    IntimacyWillingness b,
    IntimacyBoundary? aBoundary,
    IntimacyBoundary? bBoundary,
    DateTime at,
  ) {
    if (aBoundary?.blocked == true || bBoundary?.blocked == true) {
      return IntimacyDecisionKind.blocked;
    }
    if (a.isCoolingDownAt(at) || b.isCoolingDownAt(at)) {
      return IntimacyDecisionKind.blocked;
    }
    if (_isNo(a.willingness) || _isNo(b.willingness)) {
      return IntimacyDecisionKind.blocked;
    }
    if (aBoundary?.askFirst == true ||
        bBoundary?.askFirst == true ||
        _needsAsk(a.willingness) ||
        _needsAsk(b.willingness)) {
      return IntimacyDecisionKind.askFirst;
    }
    if (a.willingness == CurrentWillingness.yes &&
        b.willingness == CurrentWillingness.yes) {
      return IntimacyDecisionKind.mutuallyWilling;
    }
    return IntimacyDecisionKind.blocked;
  }

  bool _intimacyAllowed({
    required String ownerId,
    required String recipientId,
    required String category,
    required DateTime at,
    required Iterable<RelationshipCategoryGrant> grants,
  }) =>
      firewall
          .evaluate(
            request: RelationshipAccessRequest(
              ownerId: ownerId,
              recipientId: recipientId,
              category: category,
              capability: RelationshipCapability.intimacy,
              at: at,
            ),
            grants: grants,
          )
          .allowed;
}

bool _isNo(CurrentWillingness value) =>
    value == CurrentWillingness.no || value == CurrentWillingness.notTonight;

bool _needsAsk(CurrentWillingness value) =>
    value == CurrentWillingness.askFirst || value == CurrentWillingness.maybe;

void _requireIntimacyText(String value, String field) {
  if (value.trim().isEmpty) {
    throw RelationshipPolicyException('$field must not be blank');
  }
}
