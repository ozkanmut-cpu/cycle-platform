import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 9);

  group('RelationshipPresetExpander', () {
    const expander = RelationshipPresetExpander();

    test('full transparency expands every capability with raw visibility', () {
      final grants = expander.grantsFromPreset(
        preset: RelationshipSharingPreset.fullTransparency,
        categories: const ['mood', 'sleep'],
        ownerId: 'a',
        recipientId: 'b',
        createdAt: now,
      );
      expect(grants, hasLength(2));
      expect(grants.first.capabilities,
          containsAll(RelationshipCapability.values));
      expect(grants.first.visibility, RelationshipVisibility.fullyShared);
    });

    test('minimal remains engine-only and does not imply view', () {
      final grant = expander
          .grantsFromPreset(
            preset: RelationshipSharingPreset.minimal,
            categories: const ['mood'],
            ownerId: 'a',
            recipientId: 'b',
            createdAt: now,
          )
          .single;
      expect(grant.capabilities,
          {RelationshipCapability.relationshipIntelligence});
      expect(grant.visibility, RelationshipVisibility.engineOnly);
    });

    test('custom preset never invents permissions', () {
      final expansion = expander.expand(
        preset: RelationshipSharingPreset.custom,
        categories: const ['mood'],
      );
      expect(expansion.capabilitiesByCategory, isEmpty);
      expect(expansion.visibilityByCategory, isEmpty);
    });
  });

  group('CoupleContextEngine', () {
    test(
        'keeps owner scope and chooses newest entry per category deterministically',
        () {
      const expander = RelationshipPresetExpander();
      final grants = expander.grantsFromPreset(
        preset: RelationshipSharingPreset.fullTransparency,
        categories: const ['mood', 'sleep'],
        ownerId: 'a',
        recipientId: 'b',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      final context = const CoupleContextEngine().build<String>(
        ownerId: 'a',
        recipientId: 'b',
        capability: RelationshipCapability.view,
        at: now,
        grants: grants,
        entries: [
          CoupleContextEntry(
              ownerId: 'a',
              category: 'mood',
              observedAt: now.subtract(const Duration(hours: 2)),
              visibility: RelationshipVisibility.fullyShared,
              value: 'old'),
          CoupleContextEntry(
              ownerId: 'a',
              category: 'mood',
              observedAt: now.subtract(const Duration(hours: 1)),
              visibility: RelationshipVisibility.fullyShared,
              value: 'new'),
          CoupleContextEntry(
              ownerId: 'a',
              category: 'sleep',
              observedAt: now,
              visibility: RelationshipVisibility.fullyShared,
              value: 'ok'),
          CoupleContextEntry(
              ownerId: 'other',
              category: 'mood',
              observedAt: now,
              visibility: RelationshipVisibility.fullyShared,
              value: 'must-not-leak'),
        ],
      );
      expect(context.projections.map((e) => e.category).toList(),
          ['mood', 'sleep']);
      expect(context.projections.first.value, 'new');
      expect(
          context.projections.any((e) => e.value == 'must-not-leak'), isFalse);
    });

    test('engine-only context is available to engine but raw value is redacted',
        () {
      const expander = RelationshipPresetExpander();
      final grants = expander.grantsFromPreset(
        preset: RelationshipSharingPreset.minimal,
        categories: const ['mood'],
        ownerId: 'a',
        recipientId: 'b',
        createdAt: now.subtract(const Duration(hours: 1)),
      );
      final context = const CoupleContextEngine().build<String>(
        ownerId: 'a',
        recipientId: 'b',
        capability: RelationshipCapability.relationshipIntelligence,
        at: now,
        grants: grants,
        entries: [
          CoupleContextEntry(
              ownerId: 'a',
              category: 'mood',
              observedAt: now,
              visibility: RelationshipVisibility.engineOnly,
              value: 'private'),
        ],
      );
      expect(context.projections.single.visibility,
          RelationshipVisibility.engineOnly);
      expect(context.projections.single.value, isNull);
    });

    test('purpose isolation prevents view-only context from intimacy use', () {
      final grant = RelationshipCategoryGrant(
        id: 'view-only',
        ownerId: 'a',
        recipientId: 'b',
        category: 'mood',
        capabilities: const {RelationshipCapability.view},
        visibility: RelationshipVisibility.fullyShared,
        createdAt: now.subtract(const Duration(hours: 1)),
      );
      final context = const CoupleContextEngine().build<String>(
        ownerId: 'a',
        recipientId: 'b',
        capability: RelationshipCapability.intimacy,
        at: now,
        grants: [grant],
        entries: [
          CoupleContextEntry(
              ownerId: 'a',
              category: 'mood',
              observedAt: now,
              visibility: RelationshipVisibility.fullyShared,
              value: 'shared'),
        ],
      );
      expect(context.projections, isEmpty);
    });
  });
}
