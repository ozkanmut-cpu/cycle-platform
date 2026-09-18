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

  PermissionGrant revocationGrant() => PermissionGrant(
        id: 'permission-RP-001',
        ownerId: ownerId,
        recipientId: recipientId,
        recipientKind: RecipientKind.partner,
        actions: const <PermissionAction>{
          PermissionAction.view,
          PermissionAction.notify,
        },
        scope: const PermissionScope(categories: <String>{'cycle'}),
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
    Iterable<RelationshipCategoryGrant> notificationGrants = const [],
    RelationshipNotificationRequest? notificationRequest,
  }) {
    final keys = registry ?? keyRegistry();
    return PartnerSessionController(
      ownerId: ownerId,
      recipientId: recipientId,
      payloadSource: source,
      revocationGrant: revocationGrant(),
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
          expected: pairingMalformed,
        ),
        (
          name: 'expired',
          payload: invitationPayload(
            expiresAt: now.subtract(const Duration(seconds: 1)),
          ),
          expected: pairingExpired,
        ),
        (
          name: 'unsupported version',
          payload: unsupported,
          expected: pairingUnsupportedVersion,
        ),
        (name: 'unavailable', payload: null, expected: pairingUnavailable),
        (
          name: 'wrong scope',
          payload: invitationPayload(owner: 'different-owner'),
          expected: pairingScopeMismatch,
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
    expect(controller.state.errorCode, pairingMalformed);

    await controller.pair();
    expect(controller.state.paired, isTrue);
    expect(controller.state.invitation!.ownerId, 'owner-RP-001');
    expect(controller.state.errorCode, isNull);
  });

  test('unavailable production payload source returns no invitation', () async {
    expect(await const UnavailablePairingPayloadSource().acquire(), isNull);
  });

  test(
    'notification preview and disconnect delegate to production engines',
    () async {
      final registry = keyRegistry();
      final request = RelationshipNotificationRequest(
        ownerId: ownerId,
        recipientId: recipientId,
        category: 'cycle',
        categoryLabel: 'Cycle',
        detail: 'SYNTHETIC_PRIVATE_DETAIL_RP_001',
        kind: RelationshipNotificationKind.relationship,
        at: now,
      );
      final notificationGrant = RelationshipCategoryGrant(
        id: 'notify-RP-001',
        ownerId: ownerId,
        recipientId: recipientId,
        category: 'cycle',
        capabilities: const <RelationshipCapability>{
          RelationshipCapability.notify,
        },
        visibility: RelationshipVisibility.private,
        createdAt: now.subtract(const Duration(days: 1)),
      );
      final controller = controllerFor(
        source: _QueuePayloadSource(<String?>[invitationPayload()]),
        registry: registry,
        notificationRequest: request,
        notificationGrants: <RelationshipCategoryGrant>[notificationGrant],
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
