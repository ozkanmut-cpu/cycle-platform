import 'package:cycle_permissions/cycle_permissions.dart';

import 'relationship_policy.dart';

class ComposedRelationshipAccessDecision {
  const ComposedRelationshipAccessDecision._({
    required this.allowed,
    required this.reason,
    this.genericGrantId,
    this.relationshipGrantId,
  });

  const ComposedRelationshipAccessDecision.allow({
    required String genericGrantId,
    required String relationshipGrantId,
  }) : this._(
          allowed: true,
          reason: 'allowed',
          genericGrantId: genericGrantId,
          relationshipGrantId: relationshipGrantId,
        );

  const ComposedRelationshipAccessDecision.deny(String reason)
      : this._(allowed: false, reason: reason);

  final bool allowed;
  final String reason;
  final String? genericGrantId;
  final String? relationshipGrantId;
}

class RelationshipAccessGate {
  const RelationshipAccessGate({
    this.genericEvaluator = const PermissionEvaluator(),
    this.relationshipFirewall = const RelationshipPermissionFirewall(),
  });

  final PermissionEvaluator genericEvaluator;
  final RelationshipPermissionFirewall relationshipFirewall;

  ComposedRelationshipAccessDecision evaluate({
    required String ownerId,
    required String recipientId,
    required String genericCategory,
    required String relationshipCategory,
    required PermissionAction genericAction,
    required RelationshipCapability relationshipCapability,
    required DateTime at,
    required Iterable<PermissionGrant> genericGrants,
    required Iterable<RelationshipCategoryGrant> relationshipGrants,
    String? genericPurpose,
    DateTime? resourceObservedAt,
  }) {
    _validatePair(genericAction, relationshipCapability);

    final generic = genericEvaluator.evaluate(
      request: PermissionRequest(
        ownerId: ownerId,
        recipientId: recipientId,
        action: genericAction,
        category: genericCategory,
        purpose: genericPurpose,
        at: at,
        resourceObservedAt: resourceObservedAt,
      ),
      grants: genericGrants,
    );
    if (!generic.allowed) {
      return const ComposedRelationshipAccessDecision.deny('generic_denied');
    }

    final relationship = relationshipFirewall.evaluate(
      request: RelationshipAccessRequest(
        ownerId: ownerId,
        recipientId: recipientId,
        category: relationshipCategory,
        capability: relationshipCapability,
        at: at,
      ),
      grants: relationshipGrants,
    );
    if (!relationship.allowed) {
      return const ComposedRelationshipAccessDecision.deny(
        'relationship_denied',
      );
    }

    return ComposedRelationshipAccessDecision.allow(
      genericGrantId: generic.matchedGrantId!,
      relationshipGrantId: relationship.matchedGrantId!,
    );
  }
}

void _validatePair(
  PermissionAction genericAction,
  RelationshipCapability relationshipCapability,
) {
  final valid = (genericAction == PermissionAction.view &&
          relationshipCapability == RelationshipCapability.view) ||
      (genericAction == PermissionAction.notify &&
          relationshipCapability == RelationshipCapability.notify);
  if (!valid) {
    throw const RelationshipPolicyException(
      'generic and relationship capabilities must match view or notify',
    );
  }
}
