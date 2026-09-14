import 'relationship_policy.dart';

class MutualSelection {
  MutualSelection({
    required this.id,
    required this.ownerId,
    required this.partnerId,
    required this.category,
    required Set<String> optionKeys,
    required this.createdAt,
    this.expiresAt,
    this.revokedAt,
    this.version = 1,
  }) : optionKeys = Set.unmodifiable(
          optionKeys.map((e) => e.trim()).where((e) => e.isNotEmpty),
        ) {
    _requireMutualText(id, 'id');
    _requireMutualText(ownerId, 'ownerId');
    _requireMutualText(partnerId, 'partnerId');
    _requireMutualText(category, 'category');
    if (ownerId == partnerId) {
      throw const RelationshipPolicyException(
        'mutual selection owner and partner must differ',
      );
    }
    if (this.optionKeys.isEmpty) {
      throw const RelationshipPolicyException(
        'mutual selection requires at least one option',
      );
    }
    if (version <= 0) {
      throw const RelationshipPolicyException(
        'mutual selection version must be positive',
      );
    }
    if (expiresAt != null && !expiresAt!.isAfter(createdAt)) {
      throw const RelationshipPolicyException(
        'mutual selection expiresAt must be after createdAt',
      );
    }
    if (revokedAt != null && revokedAt!.isBefore(createdAt)) {
      throw const RelationshipPolicyException(
        'mutual selection revokedAt must not precede createdAt',
      );
    }
  }

  final String id;
  final String ownerId;
  final String partnerId;
  final String category;
  final Set<String> optionKeys;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final int version;

  bool isActiveAt(DateTime at) {
    if (at.isBefore(createdAt) || revokedAt != null) return false;
    return expiresAt == null || at.isBefore(expiresAt!);
  }
}

class MutualMatch {
  const MutualMatch({
    required this.id,
    required this.participantAId,
    required this.participantBId,
    required this.category,
    required this.optionKey,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String participantAId;
  final String participantBId;
  final String category;
  final String optionKey;
  final DateTime createdAt;
  final DateTime? expiresAt;
}

class MutualityEngine {
  const MutualityEngine({
    this.firewall = const RelationshipPermissionFirewall(),
  });

  final RelationshipPermissionFirewall firewall;

  List<MutualMatch> findMatches({
    required String participantAId,
    required String participantBId,
    required DateTime at,
    required Iterable<MutualSelection> selections,
    required Iterable<RelationshipCategoryGrant> grants,
  }) {
    _requireMutualText(participantAId, 'participantAId');
    _requireMutualText(participantBId, 'participantBId');
    if (participantAId == participantBId) {
      throw const RelationshipPolicyException(
        'mutuality participants must differ',
      );
    }

    final pairSelections = selections.where((selection) {
      final correctPair =
          (selection.ownerId == participantAId &&
                  selection.partnerId == participantBId) ||
              (selection.ownerId == participantBId &&
                  selection.partnerId == participantAId);
      return correctPair && selection.isActiveAt(at);
    }).toList();

    final categories = pairSelections.map((e) => e.category).toSet().toList()
      ..sort();
    final matches = <MutualMatch>[];

    for (final category in categories) {
      final a = _latestFor(
        pairSelections,
        ownerId: participantAId,
        partnerId: participantBId,
        category: category,
      );
      final b = _latestFor(
        pairSelections,
        ownerId: participantBId,
        partnerId: participantAId,
        category: category,
      );
      if (a == null || b == null) continue;

      final permissionCategory = 'relationship.mutuality.$category';
      if (!_purposeAllowed(
            ownerId: participantAId,
            recipientId: participantBId,
            category: permissionCategory,
            at: at,
            grants: grants,
          ) ||
          !_purposeAllowed(
            ownerId: participantBId,
            recipientId: participantAId,
            category: permissionCategory,
            at: at,
            grants: grants,
          )) {
        continue;
      }

      final intersection = a.optionKeys.intersection(b.optionKeys).toList()
        ..sort();
      for (final option in intersection) {
        final participants = [participantAId, participantBId]..sort();
        matches.add(
          MutualMatch(
            id: 'mutual-${participants[0]}-${participants[1]}-$category-$option',
            participantAId: participants[0],
            participantBId: participants[1],
            category: category,
            optionKey: option,
            createdAt:
                a.createdAt.isAfter(b.createdAt) ? a.createdAt : b.createdAt,
            expiresAt: _earliestExpiry(a.expiresAt, b.expiresAt),
          ),
        );
      }
    }

    matches.sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(matches);
  }

  MutualSelection? _latestFor(
    Iterable<MutualSelection> selections, {
    required String ownerId,
    required String partnerId,
    required String category,
  }) {
    final values = selections
        .where((selection) =>
            selection.ownerId == ownerId &&
            selection.partnerId == partnerId &&
            selection.category == category)
        .toList()
      ..sort((a, b) {
        final version = b.version.compareTo(a.version);
        if (version != 0) return version;
        final created = b.createdAt.compareTo(a.createdAt);
        if (created != 0) return created;
        return a.id.compareTo(b.id);
      });
    return values.isEmpty ? null : values.first;
  }

  bool _purposeAllowed({
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
              capability: RelationshipCapability.relationshipIntelligence,
              at: at,
            ),
            grants: grants,
          )
          .allowed;
}

DateTime? _earliestExpiry(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

void _requireMutualText(String value, String field) {
  if (value.trim().isEmpty) {
    throw RelationshipPolicyException('$field must not be blank');
  }
}
