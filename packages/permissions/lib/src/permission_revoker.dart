import 'permission_evaluator.dart';
import 'permission_models.dart';

typedef PermissionGrantHook = Future<void> Function(PermissionGrant grant);

class PermissionRevoker {
  const PermissionRevoker({
    this.evaluator = const PermissionEvaluator(),
    required this.onRotateRecipientKeys,
    required this.onStopNotifications,
    required this.onInvalidateExports,
  });

  final PermissionEvaluator evaluator;
  final PermissionGrantHook onRotateRecipientKeys;
  final PermissionGrantHook onStopNotifications;
  final PermissionGrantHook onInvalidateExports;

  Future<PermissionRevocationEffect> revoke(PermissionGrant grant) async {
    final effect = evaluator.revocationEffect(grant);

    if (effect.rotateRecipientKeys) {
      await onRotateRecipientKeys(grant);
    }
    if (effect.stopNotifications) {
      await onStopNotifications(grant);
    }
    if (effect.invalidateExports) {
      await onInvalidateExports(grant);
    }

    return effect;
  }
}
