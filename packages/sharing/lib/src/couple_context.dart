import 'relationship_policy.dart';

class CoupleContextEntry<T> {
  const CoupleContextEntry({
    required this.ownerId,
    required this.category,
    required this.observedAt,
    required this.visibility,
    required this.value,
  });

  final String ownerId;
  final String category;
  final DateTime observedAt;
  final RelationshipVisibility visibility;
  final T value;
}

class CoupleContext<T> {
  CoupleContext({
    required this.ownerId,
    required this.recipientId,
    required this.capability,
    required Iterable<RelationshipContextProjection<T>> projections,
  }) : projections = List.unmodifiable(projections);

  final String ownerId;
  final String recipientId;
  final RelationshipCapability capability;
  final List<RelationshipContextProjection<T>> projections;
}

class CoupleContextEngine {
  const CoupleContextEngine({
    this.projector = const RelationshipContextProjector(),
  });

  final RelationshipContextProjector projector;

  CoupleContext<T> build<T>({
    required String ownerId,
    required String recipientId,
    required RelationshipCapability capability,
    required DateTime at,
    required Iterable<CoupleContextEntry<T>> entries,
    required Iterable<RelationshipCategoryGrant> grants,
  }) {
    if (ownerId.trim().isEmpty ||
        recipientId.trim().isEmpty ||
        ownerId == recipientId) {
      throw const RelationshipPolicyException('invalid couple context scope');
    }

    final selected = entries.where((entry) => entry.ownerId == ownerId).toList()
      ..sort((a, b) {
        final category = a.category.compareTo(b.category);
        if (category != 0) return category;
        final observed = b.observedAt.compareTo(a.observedAt);
        if (observed != 0) return observed;
        return a.visibility.index.compareTo(b.visibility.index);
      });

    final projections = <RelationshipContextProjection<T>>[];
    final seenCategories = <String>{};
    for (final entry in selected) {
      if (!seenCategories.add(entry.category)) continue;
      final projection = projector.project<T>(
        item: RelationshipContextItem<T>(
          ownerId: entry.ownerId,
          category: entry.category,
          value: entry.value,
          observedAt: entry.observedAt,
          visibility: entry.visibility,
        ),
        recipientId: recipientId,
        capability: capability,
        at: at,
        grants: grants,
      );
      if (projection != null) projections.add(projection);
    }

    return CoupleContext<T>(
      ownerId: ownerId,
      recipientId: recipientId,
      capability: capability,
      projections: projections,
    );
  }
}
