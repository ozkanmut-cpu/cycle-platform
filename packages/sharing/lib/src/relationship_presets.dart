import 'relationship_policy.dart';

class RelationshipPresetExpansion {
  RelationshipPresetExpansion({
    required this.preset,
    required Map<String, Set<RelationshipCapability>> capabilitiesByCategory,
    required Map<String, RelationshipVisibility> visibilityByCategory,
  })  : capabilitiesByCategory = Map.unmodifiable(
          capabilitiesByCategory.map(
            (key, value) => MapEntry(key, Set.unmodifiable(value)),
          ),
        ),
        visibilityByCategory = Map.unmodifiable(visibilityByCategory);

  final RelationshipSharingPreset preset;
  final Map<String, Set<RelationshipCapability>> capabilitiesByCategory;
  final Map<String, RelationshipVisibility> visibilityByCategory;
}

class RelationshipPresetExpander {
  const RelationshipPresetExpander();

  RelationshipPresetExpansion expand({
    required RelationshipSharingPreset preset,
    required Iterable<String> categories,
  }) {
    final normalized = categories
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (preset == RelationshipSharingPreset.custom) {
      return RelationshipPresetExpansion(
        preset: preset,
        capabilitiesByCategory: const {},
        visibilityByCategory: const {},
      );
    }

    final caps = <String, Set<RelationshipCapability>>{};
    final visibility = <String, RelationshipVisibility>{};
    for (final category in normalized) {
      switch (preset) {
        case RelationshipSharingPreset.minimal:
          caps[category] = {RelationshipCapability.relationshipIntelligence};
          visibility[category] = RelationshipVisibility.engineOnly;
        case RelationshipSharingPreset.support:
          caps[category] = {
            RelationshipCapability.relationshipIntelligence,
            RelationshipCapability.notify,
          };
          visibility[category] = RelationshipVisibility.engineOnly;
        case RelationshipSharingPreset.closePartner:
          caps[category] = {
            RelationshipCapability.view,
            RelationshipCapability.notify,
            RelationshipCapability.relationshipIntelligence,
            RelationshipCapability.playful,
          };
          visibility[category] = RelationshipVisibility.abstractShared;
        case RelationshipSharingPreset.fullTransparency:
          caps[category] = RelationshipCapability.values
              .where(
                  (capability) => capability != RelationshipCapability.intimacy)
              .toSet();
          visibility[category] = RelationshipVisibility.fullyShared;
        case RelationshipSharingPreset.custom:
          throw StateError('custom handled above');
      }
    }
    return RelationshipPresetExpansion(
      preset: preset,
      capabilitiesByCategory: caps,
      visibilityByCategory: visibility,
    );
  }

  List<RelationshipCategoryGrant> grantsFromPreset({
    required RelationshipSharingPreset preset,
    required Iterable<String> categories,
    required String ownerId,
    required String recipientId,
    required DateTime createdAt,
    DateTime? validUntil,
    int version = 1,
  }) {
    final expansion = expand(preset: preset, categories: categories);
    final result = <RelationshipCategoryGrant>[];
    for (final category in expansion.capabilitiesByCategory.keys.toList()
      ..sort()) {
      result.add(
        RelationshipCategoryGrant(
          id: 'rel-$ownerId-$recipientId-$category-${preset.name}-v$version',
          ownerId: ownerId,
          recipientId: recipientId,
          category: category,
          capabilities: expansion.capabilitiesByCategory[category]!,
          visibility: expansion.visibilityByCategory[category]!,
          createdAt: createdAt,
          validUntil: validUntil,
          version: version,
        ),
      );
    }
    return List.unmodifiable(result);
  }
}
