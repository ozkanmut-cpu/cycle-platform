import 'package:cycle_permissions/cycle_permissions.dart';

class ShareCapabilityDecision {
  const ShareCapabilityDecision({
    required this.canView,
    required this.canNotify,
    required this.canBackup,
  });

  final bool canView;
  final bool canNotify;
  final bool canBackup;
}

class SharePolicy {
  const SharePolicy({this.evaluator = const PermissionEvaluator()});

  final PermissionEvaluator evaluator;

  ShareCapabilityDecision evaluate({
    required String ownerId,
    required String recipientId,
    required String category,
    required DateTime at,
    required Iterable<PermissionGrant> grants,
    DateTime? resourceObservedAt,
  }) {
    bool allowed(PermissionAction action) => evaluator
        .evaluate(
          request: PermissionRequest(
            ownerId: ownerId,
            recipientId: recipientId,
            action: action,
            category: category,
            at: at,
            resourceObservedAt: resourceObservedAt,
          ),
          grants: grants,
        )
        .allowed;

    return ShareCapabilityDecision(
      canView: allowed(PermissionAction.view),
      canNotify: allowed(PermissionAction.notify),
      canBackup: allowed(PermissionAction.backup),
    );
  }
}
