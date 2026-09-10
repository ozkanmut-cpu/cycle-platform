import 'package:cycle_permissions/cycle_permissions.dart';

abstract interface class RecipientKeyRotator {
  Future<String> rotate({
    required String ownerId,
    required String recipientId,
    required DateTime at,
  });
}

class RevocationResult {
  const RevocationResult({
    required this.grantId,
    required this.newKeyEnvelopeId,
    required this.notificationsStopped,
  });

  final String grantId;
  final String newKeyEnvelopeId;
  final bool notificationsStopped;
}

class SharingRevocationCoordinator {
  const SharingRevocationCoordinator({
    this.evaluator = const PermissionEvaluator(),
  });

  final PermissionEvaluator evaluator;

  Future<RevocationResult> revoke({
    required PermissionGrant grant,
    required RecipientKeyRotator keyRotator,
    required DateTime at,
  }) async {
    final effect = evaluator.revocationEffect(grant);
    final newKeyEnvelopeId = effect.rotateRecipientKeys
        ? await keyRotator.rotate(
            ownerId: grant.ownerId,
            recipientId: grant.recipientId,
            at: at,
          )
        : '';
    return RevocationResult(
      grantId: grant.id,
      newKeyEnvelopeId: newKeyEnvelopeId,
      notificationsStopped: effect.stopNotifications,
    );
  }
}
