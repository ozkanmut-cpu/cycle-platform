import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 8);

  RelationshipCategoryGrant grant({
    String owner = 'owner-a',
    String recipient = 'partner-b',
    String category = 'mood',
    Set<RelationshipCapability> capabilities = const {
      RelationshipCapability.relationshipIntelligence,
    },
    RelationshipVisibility visibility = RelationshipVisibility.engineOnly,
    DateTime? revokedAt,
    int version = 1,
  }) =>
      RelationshipCategoryGrant(
        id: 'grant-$version',
        ownerId: owner,
        recipientId: recipient,
        category: category,
        capabilities: capabilities,
        visibility: visibility,
        createdAt: now.subtract(const Duration(hours: 1)),
        validUntil: now.add(const Duration(hours: 1)),
        revokedAt: revokedAt,
        version: version,
      );

  group('RelationshipPermissionFirewall', () {
    const firewall = RelationshipPermissionFirewall();

    test('allows only an explicitly granted purpose capability', () {
      final grants = [grant()];
      final relationship = firewall.evaluate(
        request: RelationshipAccessRequest(
          ownerId: 'owner-a',
          recipientId: 'partner-b',
          category: 'mood',
          capability: RelationshipCapability.relationshipIntelligence,
          at: now,
        ),
        grants: grants,
      );
      final intimacy = firewall.evaluate(
        request: RelationshipAccessRequest(
          ownerId: 'owner-a',
          recipientId: 'partner-b',
          category: 'mood',
          capability: RelationshipCapability.intimacy,
          at: now,
        ),
        grants: grants,
      );

      expect(relationship.allowed, isTrue);
      expect(relationship.visibility, RelationshipVisibility.engineOnly);
      expect(intimacy.allowed, isFalse);
    });

    test('fails closed for a different recipient or owner', () {
      final grants = [grant()];
      for (final request in [
        RelationshipAccessRequest(
          ownerId: 'owner-a',
          recipientId: 'partner-c',
          category: 'mood',
          capability: RelationshipCapability.relationshipIntelligence,
          at: now,
        ),
        RelationshipAccessRequest(
          ownerId: 'owner-x',
          recipientId: 'partner-b',
          category: 'mood',
          capability: RelationshipCapability.relationshipIntelligence,
          at: now,
        ),
      ]) {
        expect(firewall.evaluate(request: request, grants: grants).allowed,
            isFalse);
      }
    });

    test('revoked grant immediately fails closed', () {
      final decision = firewall.evaluate(
        request: RelationshipAccessRequest(
          ownerId: 'owner-a',
          recipientId: 'partner-b',
          category: 'mood',
          capability: RelationshipCapability.relationshipIntelligence,
          at: now,
        ),
        grants: [grant(revokedAt: now)],
      );
      expect(decision.allowed, isFalse);
    });

    test('newest matching version is selected deterministically', () {
      final decision = firewall.evaluate(
        request: RelationshipAccessRequest(
          ownerId: 'owner-a',
          recipientId: 'partner-b',
          category: 'mood',
          capability: RelationshipCapability.relationshipIntelligence,
          at: now,
        ),
        grants: [grant(version: 1), grant(version: 2)],
      );
      expect(decision.matchedGrantId, 'grant-2');
    });
  });

  group('Relationship visibility', () {
    test('engine-only context can be used without exposing raw value', () {
      final projection = const RelationshipContextProjector().project<String>(
        item: RelationshipContextItem<String>(
          ownerId: 'owner-a',
          category: 'mood',
          value: 'private-source-value',
          observedAt: now,
          visibility: RelationshipVisibility.engineOnly,
        ),
        recipientId: 'partner-b',
        capability: RelationshipCapability.relationshipIntelligence,
        at: now,
        grants: [grant()],
      );
      expect(projection, isNotNull);
      expect(projection!.value, isNull);
      expect(projection.exposesRawValue, isFalse);
    });

    test('fully shared context can expose raw value when view is granted', () {
      final fullGrant = grant(
        capabilities: const {
          RelationshipCapability.view,
          RelationshipCapability.relationshipIntelligence,
        },
        visibility: RelationshipVisibility.fullyShared,
      );
      final projection = const RelationshipContextProjector().project<String>(
        item: RelationshipContextItem<String>(
          ownerId: 'owner-a',
          category: 'mood',
          value: 'shared-value',
          observedAt: now,
          visibility: RelationshipVisibility.fullyShared,
        ),
        recipientId: 'partner-b',
        capability: RelationshipCapability.view,
        at: now,
        grants: [fullGrant],
      );
      expect(projection!.value, 'shared-value');
      expect(projection.exposesRawValue, isTrue);
    });

    test('visible data cannot be reused for intimacy without purpose grant',
        () {
      final viewOnly = grant(
        capabilities: const {RelationshipCapability.view},
        visibility: RelationshipVisibility.fullyShared,
      );
      final projection = const RelationshipContextProjector().project<String>(
        item: RelationshipContextItem<String>(
          ownerId: 'owner-a',
          category: 'mood',
          value: 'shared-value',
          observedAt: now,
          visibility: RelationshipVisibility.fullyShared,
        ),
        recipientId: 'partner-b',
        capability: RelationshipCapability.intimacy,
        at: now,
        grants: [viewOnly],
      );
      expect(projection, isNull);
    });

    test('invalid visibility/capability combinations are rejected', () {
      expect(
        () => grant(
          capabilities: const {RelationshipCapability.view},
          visibility: RelationshipVisibility.engineOnly,
        ),
        throwsA(isA<RelationshipPolicyException>()),
      );
    });
  });
}
