import 'package:cycle_partner/main.dart';
import 'package:cycle_partner/partner_session.dart';
import 'package:cycle_permissions/cycle_permissions.dart';
import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 9, 18, 9);
const _ownerId = 'owner-RP-001';
const _recipientId = 'recipient-RP-001';
const _sensitiveDetail = 'SYNTHETIC_PRIVATE_DETAIL_RP_001';

PartnerSessionController _sessionController({String? payload}) {
  final registry = RecipientKeyRegistry(
    initial: <RecipientKeyState>[
      RecipientKeyState(
        ownerId: _ownerId,
        recipientId: _recipientId,
        keyEnvelopeId: 'envelope-RP-001-v1',
        version: 1,
        createdAt: _now.subtract(const Duration(days: 1)),
      ),
    ],
  );
  return PartnerSessionController(
    ownerId: _ownerId,
    recipientId: _recipientId,
    payloadSource: _SinglePayloadSource(payload),
    revocationGrant: PermissionGrant(
      id: 'permission-RP-001',
      ownerId: _ownerId,
      recipientId: _recipientId,
      recipientKind: RecipientKind.partner,
      actions: const <PermissionAction>{
        PermissionAction.view,
        PermissionAction.notify,
      },
      scope: const PermissionScope(categories: <String>{'cycle'}),
      createdAt: _now.subtract(const Duration(days: 1)),
    ),
    keyRotator: RegistryRecipientKeyRotator(
      registry: registry,
      keyEnvelopeIdFactory: () => 'envelope-RP-001-v2',
    ),
    notificationGrants: <RelationshipCategoryGrant>[
      RelationshipCategoryGrant(
        id: 'notify-RP-001',
        ownerId: _ownerId,
        recipientId: _recipientId,
        category: 'cycle',
        capabilities: const <RelationshipCapability>{
          RelationshipCapability.notify,
        },
        visibility: RelationshipVisibility.private,
        createdAt: _now.subtract(const Duration(days: 1)),
      ),
    ],
    notificationRequest: RelationshipNotificationRequest(
      ownerId: _ownerId,
      recipientId: _recipientId,
      category: 'cycle',
      categoryLabel: 'Cycle',
      detail: _sensitiveDetail,
      kind: RelationshipNotificationKind.relationship,
      at: _now,
    ),
    now: () => _now,
  );
}

Future<PartnerSessionController> pairedController() async {
  const codec = PairingQrCodec();
  final payload = codec.encode(
    PairingInvitation(
      ownerId: _ownerId,
      recipientId: _recipientId,
      keyEnvelopeId: 'envelope-RP-001-v1',
      nonce: 'nonce-RP-001',
      expiresAt: _now.add(const Duration(minutes: 10)),
    ),
  );
  final controller = _sessionController(payload: payload);
  await controller.pair();
  return controller;
}

RelationshipHomeModel _sharedHealthModel() => RelationshipHomeModel(
      cards: const <RelationshipHomeCard>[
        RelationshipHomeCard(
          id: 'health-energy',
          tab: RelationshipHomeTab.sharedHealth,
          kind: RelationshipHomeCardKind.sharedHealth,
          reference: 'health.energy',
          visibility: RelationshipVisibility.fullyShared,
          rawValue: 'steady',
        ),
      ],
    );

void main() {
  testWidgets('Partner Home exposes four privacy-safe relationship tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const CyclePartnerApp());

    expect(find.text('Cycle Partner'), findsOneWidget);
    expect(find.text('Read-only'), findsOneWidget);
    expect(find.text('Now'), findsWidgets);
    expect(find.text('Us'), findsOneWidget);
    expect(find.text('Surprise'), findsOneWidget);
    expect(find.text('Shared Health'), findsOneWidget);
    expect(find.text('Nothing to surface right now'), findsOneWidget);

    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();
    expect(find.text('No shared health details to show'), findsOneWidget);
    expect(
      find.textContaining('does not indicate whether health data exists'),
      findsOneWidget,
    );
  });

  testWidgets('engine-only context is not rendered by partner home', (
    tester,
  ) async {
    final model = RelationshipHomeModel(
      cards: const [
        RelationshipHomeCard(
          id: 'hidden',
          tab: RelationshipHomeTab.us,
          kind: RelationshipHomeCardKind.memory,
          reference: 'private-context',
          visibility: RelationshipVisibility.engineOnly,
        ),
      ],
    );

    await tester.pumpWidget(CyclePartnerApp(homeModel: model));
    await tester.tap(find.text('Us'));
    await tester.pumpAndSettle();

    expect(find.textContaining('private-context'), findsNothing);
  });

  testWidgets('fully shared raw health detail can render', (tester) async {
    final controller = await pairedController();
    final model = RelationshipHomeModel(
      cards: const [
        RelationshipHomeCard(
          id: 'health-energy',
          tab: RelationshipHomeTab.sharedHealth,
          kind: RelationshipHomeCardKind.sharedHealth,
          reference: 'health.energy',
          visibility: RelationshipVisibility.fullyShared,
          rawValue: 'low',
        ),
      ],
    );

    await tester.pumpWidget(
      CyclePartnerApp(homeModel: model, sessionController: controller),
    );
    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();

    expect(find.text('health.energy: low'), findsOneWidget);
  });

  testWidgets('Us keeps secure sharing controls available', (tester) async {
    await tester.pumpWidget(const CyclePartnerApp());
    await tester.tap(find.text('Us'));
    await tester.pumpAndSettle();

    expect(find.text('Sharing controls'), findsOneWidget);
    expect(find.text('VIEW'), findsOneWidget);
    expect(find.text('NOTIFY'), findsOneWidget);
    expect(find.text('BACKUP'), findsOneWidget);
    expect(find.text('Private notifications'), findsOneWidget);
  });

  testWidgets('coordinator pipeline feeds authorized cards into partner UI', (
    tester,
  ) async {
    final controller = await pairedController();
    final now = DateTime.utc(2026, 9, 14, 10);
    final input = PartnerExperienceInput(
      ownerId: 'a',
      partnerId: 'b',
      at: now,
      sharedHealthEntries: [
        CoupleContextEntry<Object?>(
          ownerId: 'a',
          category: 'health.energy',
          observedAt: now,
          visibility: RelationshipVisibility.fullyShared,
          value: 'steady',
        ),
      ],
      grants: [
        RelationshipCategoryGrant(
          id: 'view-energy',
          ownerId: 'a',
          recipientId: 'b',
          category: 'health.energy',
          capabilities: {RelationshipCapability.view},
          visibility: RelationshipVisibility.fullyShared,
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
      ],
    );

    await tester.pumpWidget(
      CyclePartnerApp(experienceInput: input, sessionController: controller),
    );
    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();

    expect(find.text('health.energy: steady'), findsOneWidget);
  });

  testWidgets('coordinator pipeline keeps engine-only health hidden', (
    tester,
  ) async {
    final controller = await pairedController();
    final now = DateTime.utc(2026, 9, 14, 10);
    final input = PartnerExperienceInput(
      ownerId: 'a',
      partnerId: 'b',
      at: now,
      sharedHealthEntries: [
        CoupleContextEntry<Object?>(
          ownerId: 'a',
          category: 'health.sleep',
          observedAt: now,
          visibility: RelationshipVisibility.engineOnly,
          value: 'poor',
        ),
      ],
      grants: [
        RelationshipCategoryGrant(
          id: 'engine-sleep',
          ownerId: 'a',
          recipientId: 'b',
          category: 'health.sleep',
          capabilities: {RelationshipCapability.relationshipIntelligence},
          visibility: RelationshipVisibility.engineOnly,
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
      ],
    );

    await tester.pumpWidget(
      CyclePartnerApp(experienceInput: input, sessionController: controller),
    );
    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();

    expect(find.textContaining('health.sleep'), findsNothing);
    expect(find.textContaining('poor'), findsNothing);
    expect(find.text('No shared health details to show'), findsOneWidget);
  });

  testWidgets('partner cards require a valid paired session', (tester) async {
    final controller = _sessionController();

    await tester.pumpWidget(
      CyclePartnerApp(
        homeModel: _sharedHealthModel(),
        sessionController: controller,
      ),
    );
    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();

    expect(find.text('health.energy: steady'), findsNothing);
    expect(find.text('No shared health details to show'), findsOneWidget);
  });

  testWidgets('pairing, malformed retry, and disconnect update card visibility',
      (
    tester,
  ) async {
    final malformed = _sessionController(payload: 'not-a-pairing-payload');
    await tester.pumpWidget(
      CyclePartnerApp(
        homeModel: _sharedHealthModel(),
        sessionController: malformed,
      ),
    );
    await tester.tap(find.text('Scan pairing QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();
    expect(find.text('health.energy: steady'), findsNothing);
    expect(
      find.text('That pairing QR could not be read. Try scanning it again.'),
      findsOneWidget,
    );

    final paired = await pairedController();
    await tester.pumpWidget(
      CyclePartnerApp(
        homeModel: _sharedHealthModel(),
        sessionController: paired,
      ),
    );
    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();
    expect(find.text('health.energy: steady'), findsOneWidget);

    await tester.tap(find.text('Us'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();
    expect(find.text('health.energy: steady'), findsNothing);
  });

  testWidgets('pairing errors show stable recovery copy and retain retry', (
    tester,
  ) async {
    final cases = <({String? payload, String message})>[
      (
        payload: null,
        message:
            'Pairing scanner is unavailable. Try again when scanning is available.',
      ),
      (
        payload: 'not-a-pairing-payload',
        message: 'That pairing QR could not be read. Try scanning it again.',
      ),
    ];

    for (final testCase in cases) {
      final controller = _sessionController(payload: testCase.payload);
      await tester.pumpWidget(
        CyclePartnerApp(sessionController: controller),
      );
      await tester.tap(find.text('Scan pairing QR'));
      await tester.pumpAndSettle();

      expect(find.text(testCase.message), findsOneWidget);
      expect(find.text('Scan pairing QR'), findsOneWidget);
    }
  });

  testWidgets('notification preview renders production-redacted output', (
    tester,
  ) async {
    final controller = await pairedController();
    await tester.pumpWidget(CyclePartnerApp(sessionController: controller));
    await tester.tap(find.text('Us'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preview notification'));
    await tester.pumpAndSettle();

    expect(find.text('Cycle'), findsOneWidget);
    expect(find.text('You have a private partner update.'), findsOneWidget);
    expect(find.text(_sensitiveDetail), findsNothing);
    expect(find.bySemanticsLabel('Redacted'), findsOneWidget);
  });

  testWidgets('privacy selection delegates to the session controller', (
    tester,
  ) async {
    final controller = await pairedController();
    await tester.pumpWidget(CyclePartnerApp(sessionController: controller));
    await tester.tap(find.text('Us'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detailed when unlocked').last);
    await tester.pumpAndSettle();

    expect(
      controller.state.privacyMode,
      NotificationPrivacyMode.detailedWhenUnlocked,
    );
  });

  testWidgets('controller replacement preserves caller ownership', (
    tester,
  ) async {
    final first = _sessionController();
    final second = _sessionController();

    await tester.pumpWidget(const CyclePartnerApp());
    await tester.pumpWidget(CyclePartnerApp(sessionController: first));
    await tester.pumpWidget(CyclePartnerApp(sessionController: second));
    await tester.pumpWidget(const SizedBox.shrink());

    expect(
      () => first.setPrivacyMode(NotificationPrivacyMode.categoryOnly),
      returnsNormally,
    );
    expect(
      () => second.setPrivacyMode(NotificationPrivacyMode.categoryOnly),
      returnsNormally,
    );
  });
}

class _SinglePayloadSource implements PairingPayloadSource {
  _SinglePayloadSource(this.payload);

  final String? payload;

  @override
  Future<String?> acquire() async => payload;
}
