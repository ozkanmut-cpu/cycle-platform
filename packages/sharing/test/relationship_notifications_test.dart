import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 10);

  RelationshipCategoryGrant grant(
    String id,
    RelationshipCapability capability,
  ) =>
      RelationshipCategoryGrant(
        id: id,
        ownerId: 'a',
        recipientId: 'b',
        category: 'relationship.support',
        capabilities: {capability},
        visibility: RelationshipVisibility.engineOnly,
        createdAt: now.subtract(const Duration(minutes: 1)),
      );

  RelationshipNotificationRequest request(
    RelationshipNotificationKind kind,
  ) =>
      RelationshipNotificationRequest(
        ownerId: 'a',
        recipientId: 'b',
        category: 'relationship.support',
        categoryLabel: 'Support',
        detail: 'A small check-in could help.',
        kind: kind,
        at: now,
      );

  test('NOTIFY is required even when VIEW exists', () {
    final view = RelationshipCategoryGrant(
      id: 'view',
      ownerId: 'a',
      recipientId: 'b',
      category: 'relationship.support',
      capabilities: {RelationshipCapability.view},
      visibility: RelationshipVisibility.fullyShared,
      createdAt: now.subtract(const Duration(minutes: 1)),
    );

    final result = const RelationshipNotificationPipeline().present(
      request: request(RelationshipNotificationKind.relationship),
      mode: NotificationPrivacyMode.detailedWhenUnlocked,
      deviceUnlocked: true,
      grants: [view],
    );
    expect(result, isNull);
  });

  test('NOTIFY can present detail without granting VIEW', () {
    final result = const RelationshipNotificationPipeline().present(
      request: request(RelationshipNotificationKind.relationship),
      mode: NotificationPrivacyMode.detailedWhenUnlocked,
      deviceUnlocked: true,
      grants: [grant('notify', RelationshipCapability.notify)],
    );

    expect(result, isNotNull);
    expect(result!.body, 'A small check-in could help.');
    expect(result.redacted, isFalse);
  });

  test('category-only mode never exposes detail', () {
    final result = const RelationshipNotificationPipeline().present(
      request: request(RelationshipNotificationKind.relationship),
      mode: NotificationPrivacyMode.categoryOnly,
      deviceUnlocked: true,
      grants: [grant('notify', RelationshipCapability.notify)],
    );

    expect(result!.body, 'New Support update.');
    expect(result.body, isNot(contains('check-in')));
    expect(result.redacted, isTrue);
  });

  test('detailed mode falls back to generic while locked', () {
    final result = const RelationshipNotificationPipeline().present(
      request: request(RelationshipNotificationKind.relationship),
      mode: NotificationPrivacyMode.detailedWhenUnlocked,
      deviceUnlocked: false,
      grants: [grant('notify', RelationshipCapability.notify)],
    );

    expect(result!.body, 'You have a private partner update.');
    expect(result.redacted, isTrue);
  });

  test('playful notification requires NOTIFY and PLAYFUL', () {
    final pipeline = const RelationshipNotificationPipeline();
    final onlyNotify = pipeline.present(
      request: request(RelationshipNotificationKind.playful),
      mode: NotificationPrivacyMode.generic,
      deviceUnlocked: false,
      grants: [grant('notify', RelationshipCapability.notify)],
    );
    expect(onlyNotify, isNull);

    final allowed = pipeline.present(
      request: request(RelationshipNotificationKind.playful),
      mode: NotificationPrivacyMode.generic,
      deviceUnlocked: false,
      grants: [
        grant('notify', RelationshipCapability.notify),
        grant('playful', RelationshipCapability.playful),
      ],
    );
    expect(allowed, isNotNull);
  });

  test('intimacy notification requires NOTIFY and INTIMACY', () {
    final result = const RelationshipNotificationPipeline().present(
      request: request(RelationshipNotificationKind.intimacy),
      mode: NotificationPrivacyMode.detailedWhenUnlocked,
      deviceUnlocked: true,
      grants: [
        grant('notify', RelationshipCapability.notify),
        grant('intimacy', RelationshipCapability.intimacy),
      ],
    );
    expect(result, isNotNull);

    final denied = const RelationshipNotificationPipeline().present(
      request: request(RelationshipNotificationKind.intimacy),
      mode: NotificationPrivacyMode.detailedWhenUnlocked,
      deviceUnlocked: true,
      grants: [grant('notify', RelationshipCapability.notify)],
    );
    expect(denied, isNull);
  });

  test('playful intimacy requires both content capabilities', () {
    final result = const RelationshipNotificationPipeline().present(
      request: request(RelationshipNotificationKind.playfulIntimacy),
      mode: NotificationPrivacyMode.generic,
      deviceUnlocked: false,
      grants: [
        grant('notify', RelationshipCapability.notify),
        grant('playful', RelationshipCapability.playful),
      ],
    );
    expect(result, isNull);
  });
}
