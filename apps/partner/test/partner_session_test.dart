import 'dart:convert';

import 'package:cycle_partner/partner_session.dart';
import 'package:cycle_permissions/cycle_permissions.dart';
import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18, 9);
  const ownerId = 'owner-RP-001';
  const recipientId = 'recipient-RP-001';
  const codec = PairingQrCodec();

  String invitationPayload({
    String owner = ownerId,
    String recipient = recipientId,
    DateTime? expiresAt,
  }) =>
      codec.encode(
        PairingInvitation(
          ownerId: owner,
          recipientId: recipient,
          keyEnvelopeId: 'envelope-RP-001-v1',
          nonce: 'nonce-RP-001',
          expiresAt: expiresAt ?? now.add(const Duration(minutes: 10)),
        ),
      );

  PermissionGrant revocationGrant({
    String owner = ownerId,
    String recipient = recipientId,
    DateTime? revokedAt,
  }) =>
      PermissionGrant(
        id: 'permission-RP-001',
        ownerId: owner,
        recipientId: recipient,
        recipientKind: RecipientKind.partner,
        actions: const <PermissionAction>{
          PermissionAction.view,
          PermissionAction.notify,
        },
        scope: const PermissionScope(categories: <String>{'cycle'}),
        createdAt: now.subtract(const Duration(days: 1)),
        revokedAt: revokedAt,
      );

  RelationshipNotificationRequest notificationRequest({
    String owner = ownerId,
    String recipient = recipientId,
  }) =>
      RelationshipNotificationRequest(
        ownerId: owner,
        recipientId: recipient,
        category: 'cycle',
        categoryLabel: 'Cycle',
        detail: 'SYNTHETIC_PRIVATE_DETAIL_RP_001',
        kind: RelationshipNotificationKind.relationship,
        at: now,
      );

  RelationshipCategoryGrant notificationGrant({
    String owner = ownerId,
    String recipient = recipientId,
  }) =>
      RelationshipCategoryGrant(
        id: 'notify-RP-001',
        ownerId: owner,
        recipientId: recipient,
        category: 'cycle',
        capabilities: const <RelationshipCapability>{
          RelationshipCapability.notify,
        },
        visibility: RelationshipVisibility.private,
        createdAt: now.subtract(const Duration(days: 1)),
      );

  RecipientKeyRegistry keyRegistry() => RecipientKeyRegistry(
        initial: <RecipientKeyState>[
          RecipientKeyState(
            ownerId: ownerId,
            recipientId: recipientId,
            keyEnvelopeId: 'envelope-RP-001-v1',
            version: 1,
            createdAt: now.subtract(const Duration(days: 1)),
          ),
        ],
      );

  PartnerSessionController controllerFor({
    required PairingPayloadSource source,
    RecipientKeyRegistry? registry,
    PermissionGrant? configuredRevocationGrant,
    Iterable<RelationshipCategoryGrant> notificationGrants = const [],
    RelationshipNotificationRequest? notificationRequest,
  }) {
    final keys = registry ?? keyRegistry();
    return PartnerSessionController(
      ownerId: ownerId,
      recipientId: recipientId,
      payloadSource: source,
      revocationGrant: configuredRevocationGrant ?? revocationGrant(),
      keyRotator: RegistryRecipientKeyRotator(
        registry: keys,
        keyEnvelopeIdFactory: () => 'envelope-RP-001-v2',
      ),
      notificationGrants: notificationGrants,
      notificationRequest: notificationRequest,
      pairingCodec: codec,
      notificationPipeline: const RelationshipNotificationPipeline(),
      revocationCoordinator: const SharingRevocationCoordinator(),
      now: () => now,
    );
  }

  test('valid pairing records the production-validated invitation', () async {
    final controller = controllerFor(
      source: _QueuePayloadSource(<String?>[invitationPayload()]),
    );

    await controller.pair();

    expect(controller.state.paired, isTrue);
    expect(controller.state.invitation!.ownerId, 'owner-RP-001');
    expect(controller.state.invitation!.recipientId, 'recipient-RP-001');
    expect(controller.state.errorCode, isNull);
  });

  test(
    'pairing failures use stable codes and never expose codec text',
    () async {
      final unsupported = base64Url
          .encode(
            utf8.encode(
              jsonEncode(<String, Object?>{
                'v': 2,
                'ownerId': ownerId,
                'recipientId': recipientId,
                'keyEnvelopeId': 'envelope-RP-001-v1',
                'nonce': 'nonce-RP-001',
                'expiresAt':
                    now.add(const Duration(minutes: 10)).toIso8601String(),
              }),
            ),
          )
          .replaceAll('=', '');
      final cases = <({String name, String? payload, String expected})>[
        (
          name: 'malformed',
          payload: 'not-a-valid-pairing-payload',
          expected: 'pairing_malformed',
        ),
        (
          name: 'expired',
          payload: invitationPayload(
            expiresAt: now.subtract(const Duration(seconds: 1)),
          ),
          expected: 'pairing_expired',
        ),
        (
          name: 'unsupported version',
          payload: unsupported,
          expected: 'pairing_unsupported_version',
        ),
        (name: 'unavailable', payload: null, expected: 'pairing_unavailable'),
        (
          name: 'wrong scope',
          payload: invitationPayload(owner: 'different-owner'),
          expected: 'pairing_scope_mismatch',
        ),
      ];

      for (final testCase in cases) {
        final controller = controllerFor(
          source: _QueuePayloadSource(<String?>[testCase.payload]),
        );

        await controller.pair();

        expect(controller.state.paired, isFalse, reason: testCase.name);
        expect(controller.state.invitation, isNull, reason: testCase.name);
        expect(
          controller.state.errorCode,
          testCase.expected,
          reason: testCase.name,
        );
        expect(
          controller.state.errorCode,
          isNot(contains('Pairing invitation expired.')),
          reason: testCase.name,
        );
        expect(
          controller.state.errorCode,
          isNot(contains('Unsupported pairing payload version.')),
          reason: testCase.name,
        );
      }
    },
  );

  test('a failed pairing attempt can retry successfully', () async {
    final controller = controllerFor(
      source: _QueuePayloadSource(<String?>[
        'not-a-valid-pairing-payload',
        invitationPayload(),
      ]),
    );

    await controller.pair();
    expect(controller.state.paired, isFalse);
    expect(controller.state.errorCode, 'pairing_malformed');

    await controller.pair();
    expect(controller.state.paired, isTrue);
    expect(controller.state.invitation!.ownerId, 'owner-RP-001');
    expect(controller.state.errorCode, isNull);
  });

  test('unavailable production payload source returns no invitation', () async {
    expect(await const UnavailablePairingPayloadSource().acquire(), isNull);
  });

  test(
    'disconnect revokes a validated relationship after a failed re-pair',
    () async {
      final registry = keyRegistry();
      final controller = controllerFor(
        source: _QueuePayloadSource(<String?>[
          invitationPayload(),
          'not-a-valid-pairing-payload',
        ]),
        registry: registry,
      );

      await controller.pair();
      expect(controller.state.paired, isTrue);

      await controller.pair();
      expect(controller.state.paired, isFalse);
      expect(controller.state.errorCode, 'pairing_malformed');
      expect(registry.all(), hasLength(1));

      await controller.disconnect();

      expect(controller.state.paired, isFalse);
      expect(controller.state.notificationsStopped, isTrue);
      expect(
        registry.all().map((state) => state.version),
        containsAll(<int>[1, 2]),
      );
      expect(
        registry.activeFor(ownerId: ownerId, recipientId: recipientId)!.version,
        2,
      );
    },
  );

  test(
    'pairing rejects cross-relationship dependencies without side effects',
    () async {
      final cases = <({
        String name,
        PermissionGrant revocationGrant,
        RelationshipNotificationRequest notificationRequest,
        List<RelationshipCategoryGrant> notificationGrants,
      })>[
        (
          name: 'revocation grant',
          revocationGrant: revocationGrant(recipient: 'other-recipient'),
          notificationRequest: notificationRequest(),
          notificationGrants: <RelationshipCategoryGrant>[
            notificationGrant(),
          ],
        ),
        (
          name: 'notification request',
          revocationGrant: revocationGrant(),
          notificationRequest: notificationRequest(
            recipient: 'other-recipient',
          ),
          notificationGrants: <RelationshipCategoryGrant>[
            notificationGrant(),
          ],
        ),
        (
          name: 'notification grant',
          revocationGrant: revocationGrant(),
          notificationRequest: notificationRequest(),
          notificationGrants: <RelationshipCategoryGrant>[
            notificationGrant(recipient: 'other-recipient'),
          ],
        ),
      ];

      for (final testCase in cases) {
        final registry = keyRegistry();
        final controller = controllerFor(
          source: _QueuePayloadSource(<String?>[invitationPayload()]),
          registry: registry,
          configuredRevocationGrant: testCase.revocationGrant,
          notificationRequest: testCase.notificationRequest,
          notificationGrants: testCase.notificationGrants,
        );

        await controller.pair();

        expect(controller.state.paired, isFalse, reason: testCase.name);
        expect(
          controller.state.errorCode,
          'pairing_scope_mismatch',
          reason: testCase.name,
        );

        controller.previewNotification();
        expect(controller.state.preview, isNull, reason: testCase.name);

        await controller.disconnect();

        expect(registry.all(), hasLength(1), reason: testCase.name);
        expect(registry.all().single.version, 1, reason: testCase.name);
        expect(registry.all().single.isRevoked, isFalse, reason: testCase.name);
      }
    },
  );

  test(
    'pairing rejects an inactive revocation grant without key rotation',
    () async {
      final registry = keyRegistry();
      final controller = controllerFor(
        source: _QueuePayloadSource(<String?>[invitationPayload()]),
        registry: registry,
        configuredRevocationGrant: revocationGrant(
          revokedAt: now.subtract(const Duration(minutes: 1)),
        ),
      );

      await controller.pair();

      expect(controller.state.paired, isFalse);
      expect(controller.state.errorCode, 'pairing_scope_mismatch');

      await controller.disconnect();

      expect(registry.all(), hasLength(1));
      expect(registry.all().single.version, 1);
      expect(registry.all().single.isRevoked, isFalse);
    },
  );

  test(
    'notification preview and disconnect delegate to production engines',
    () async {
      final registry = keyRegistry();
      final controller = controllerFor(
        source: _QueuePayloadSource(<String?>[invitationPayload()]),
        registry: registry,
        notificationRequest: notificationRequest(),
        notificationGrants: <RelationshipCategoryGrant>[
          notificationGrant(),
        ],
      );
      await controller.pair();

      controller.setPrivacyMode(NotificationPrivacyMode.detailedWhenUnlocked);
      controller.setDeviceUnlocked(false);
      controller.previewNotification();

      expect(controller.state.preview, isNotNull);
      expect(controller.state.preview!.redacted, isTrue);
      expect(
        controller.state.preview!.body,
        isNot(contains('SYNTHETIC_PRIVATE_DETAIL_RP_001')),
      );

      await controller.disconnect();

      expect(controller.state.paired, isFalse);
      expect(controller.state.invitation, isNull);
      expect(controller.state.preview, isNull);
      expect(controller.state.notificationsStopped, isTrue);
      expect(
        registry.all().map((state) => state.version),
        containsAll(<int>[1, 2]),
      );
      expect(
        registry.all().singleWhere((state) => state.version == 1).isRevoked,
        isTrue,
      );
      expect(
        registry.activeFor(ownerId: ownerId, recipientId: recipientId)!.version,
        2,
      );
    },
  );
}

class _QueuePayloadSource implements PairingPayloadSource {
  _QueuePayloadSource(this._payloads);

  final List<String?> _payloads;

  @override
  Future<String?> acquire() async => _payloads.removeAt(0);
}
