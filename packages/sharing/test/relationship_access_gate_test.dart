import 'package:cycle_permissions/cycle_permissions.dart';
import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 11);

  PermissionGrant generic(PermissionAction action, {DateTime? revokedAt}) =>
      PermissionGrant(
        id: 'generic-${action.name}',
        ownerId: 'a',
        recipientId: 'b',
        recipientKind: RecipientKind.partner,
        actions: {action},
        scope: const PermissionScope(categories: {'health.energy'}),
        createdAt: now.subtract(const Duration(hours: 2)),
        revokedAt: revokedAt,
      );

  RelationshipCategoryGrant relationship(
    RelationshipCapability capability, {
    DateTime? revokedAt,
  }) =>
      RelationshipCategoryGrant(
        id: 'relationship-${capability.name}',
        ownerId: 'a',
        recipientId: 'b',
        category: 'relationship.health.energy',
        capabilities: {capability},
        visibility: capability == RelationshipCapability.view
            ? RelationshipVisibility.fullyShared
            : RelationshipVisibility.engineOnly,
        createdAt: now.subtract(const Duration(hours: 2)),
        revokedAt: revokedAt,
      );

  test('VIEW requires both generic and relationship grants', () {
    final gate = const RelationshipAccessGate();
    expect(
      gate.evaluate(
        ownerId: 'a',
        recipientId: 'b',
        genericCategory: 'health.energy',
        relationshipCategory: 'relationship.health.energy',
        genericAction: PermissionAction.view,
        relationshipCapability: RelationshipCapability.view,
        at: now,
        genericGrants: [generic(PermissionAction.view)],
        relationshipGrants: [relationship(RelationshipCapability.view)],
      ).allowed,
      isTrue,
    );

    final denied = gate.evaluate(
      ownerId: 'a',
      recipientId: 'b',
      genericCategory: 'health.energy',
      relationshipCategory: 'relationship.health.energy',
      genericAction: PermissionAction.view,
      relationshipCapability: RelationshipCapability.view,
      at: now,
      genericGrants: [generic(PermissionAction.view)],
      relationshipGrants: const [],
    );
    expect(denied.allowed, isFalse);
    expect(denied.reason, 'relationship_denied');
  });

  test('NOTIFY cannot be satisfied by VIEW on either layer', () {
    expect(
      () => const RelationshipAccessGate().evaluate(
        ownerId: 'a',
        recipientId: 'b',
        genericCategory: 'health.energy',
        relationshipCategory: 'relationship.health.energy',
        genericAction: PermissionAction.view,
        relationshipCapability: RelationshipCapability.notify,
        at: now,
        genericGrants: [generic(PermissionAction.view)],
        relationshipGrants: [relationship(RelationshipCapability.notify)],
      ),
      throwsA(isA<RelationshipPolicyException>()),
    );
  });

  test('revoked grants remain valid only before revocation instant', () {
    final revokedAt = now.subtract(const Duration(minutes: 10));
    final before = revokedAt.subtract(const Duration(seconds: 1));
    final gate = const RelationshipAccessGate();
    final genericGrant = generic(PermissionAction.notify, revokedAt: revokedAt);
    final relationshipGrant = relationship(
      RelationshipCapability.notify,
      revokedAt: revokedAt,
    );

    expect(
      gate.evaluate(
        ownerId: 'a',
        recipientId: 'b',
        genericCategory: 'health.energy',
        relationshipCategory: 'relationship.health.energy',
        genericAction: PermissionAction.notify,
        relationshipCapability: RelationshipCapability.notify,
        at: before,
        genericGrants: [genericGrant],
        relationshipGrants: [relationshipGrant],
      ).allowed,
      isTrue,
    );
    expect(
      gate.evaluate(
        ownerId: 'a',
        recipientId: 'b',
        genericCategory: 'health.energy',
        relationshipCategory: 'relationship.health.energy',
        genericAction: PermissionAction.notify,
        relationshipCapability: RelationshipCapability.notify,
        at: revokedAt,
        genericGrants: [genericGrant],
        relationshipGrants: [relationshipGrant],
      ).allowed,
      isFalse,
    );
  });
}
