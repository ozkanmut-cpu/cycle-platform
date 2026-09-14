import 'notifications.dart';
import 'relationship_policy.dart';

enum RelationshipNotificationKind {
  relationship,
  playful,
  intimacy,
  playfulIntimacy,
}

class RelationshipNotificationRequest {
  RelationshipNotificationRequest({
    required this.ownerId,
    required this.recipientId,
    required this.category,
    required this.categoryLabel,
    required this.detail,
    required this.kind,
    required this.at,
  }) {
    if (ownerId.trim().isEmpty ||
        recipientId.trim().isEmpty ||
        category.trim().isEmpty ||
        categoryLabel.trim().isEmpty ||
        detail.trim().isEmpty ||
        ownerId == recipientId) {
      throw const RelationshipPolicyException(
        'invalid relationship notification request',
      );
    }
  }

  final String ownerId;
  final String recipientId;
  final String category;
  final String categoryLabel;
  final String detail;
  final RelationshipNotificationKind kind;
  final DateTime at;
}

class RelationshipNotificationPipeline {
  const RelationshipNotificationPipeline({
    this.firewall = const RelationshipPermissionFirewall(),
  });

  final RelationshipPermissionFirewall firewall;

  PrivateNotification? present({
    required RelationshipNotificationRequest request,
    required NotificationPrivacyMode mode,
    required bool deviceUnlocked,
    required Iterable<RelationshipCategoryGrant> grants,
  }) {
    if (!_allowed(
      request,
      RelationshipCapability.notify,
      grants,
    )) {
      return null;
    }

    for (final capability in _contentCapabilities(request.kind)) {
      if (!_allowed(request, capability, grants)) return null;
    }

    switch (mode) {
      case NotificationPrivacyMode.generic:
        return const PrivateNotification(
          title: 'Cycle',
          body: 'You have a private partner update.',
          redacted: true,
        );
      case NotificationPrivacyMode.categoryOnly:
        return PrivateNotification(
          title: 'Cycle',
          body: 'New ${request.categoryLabel.trim()} update.',
          redacted: true,
        );
      case NotificationPrivacyMode.detailedWhenUnlocked:
        if (!deviceUnlocked) {
          return const PrivateNotification(
            title: 'Cycle',
            body: 'You have a private partner update.',
            redacted: true,
          );
        }
        return PrivateNotification(
          title: 'Cycle · ${request.categoryLabel.trim()}',
          body: request.detail.trim(),
          redacted: false,
        );
    }
  }

  bool _allowed(
    RelationshipNotificationRequest request,
    RelationshipCapability capability,
    Iterable<RelationshipCategoryGrant> grants,
  ) =>
      firewall
          .evaluate(
            request: RelationshipAccessRequest(
              ownerId: request.ownerId,
              recipientId: request.recipientId,
              category: request.category,
              capability: capability,
              at: request.at,
            ),
            grants: grants,
          )
          .allowed;
}

Set<RelationshipCapability> _contentCapabilities(
  RelationshipNotificationKind kind,
) =>
    switch (kind) {
      RelationshipNotificationKind.relationship => const {},
      RelationshipNotificationKind.playful => const {
          RelationshipCapability.playful,
        },
      RelationshipNotificationKind.intimacy => const {
          RelationshipCapability.intimacy,
        },
      RelationshipNotificationKind.playfulIntimacy => const {
          RelationshipCapability.playful,
          RelationshipCapability.intimacy,
        },
    };
