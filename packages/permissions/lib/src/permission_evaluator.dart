import 'permission_models.dart';

class PermissionEvaluator {
  const PermissionEvaluator();

  PermissionDecision evaluate({
    required PermissionRequest request,
    required Iterable<PermissionGrant> grants,
  }) {
    for (final grant in grants) {
      if (grant.ownerId != request.ownerId) continue;
      if (grant.recipientId != request.recipientId) continue;
      if (grant.isRevoked) continue;
      if (!grant.actions.contains(request.action)) continue;
      if (!grant.scope.isActiveAt(request.at)) continue;
      if (!grant.scope.categories.contains(request.category)) continue;

      final field = request.field;
      if (field != null && !grant.scope.fields.contains(field)) continue;

      final purpose = request.purpose;
      if (purpose != null && !grant.scope.purposes.contains(purpose)) continue;

      return PermissionDecision.allow(grant.id);
    }

    return const PermissionDecision.deny('default-deny');
  }

  PermissionRevocationEffect revocationEffect(PermissionGrant grant) {
    return PermissionRevocationEffect(
      grantId: grant.id,
      rotateRecipientKeys: true,
      stopNotifications: grant.actions.contains(PermissionAction.notify),
      invalidateExports: grant.actions.contains(PermissionAction.export),
    );
  }
}
