import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/partner_journey_fixtures.dart';
import 'support/partner_journey_harness.dart';

void main() {
  test('canonical fixtures provide stable production-boundary inputs', () {
    final fixtures = <PartnerJourneyFixture>[
      rp001Fixture(),
      rp002Fixture(),
      rp005Fixture(),
    ];

    expect(canonicalPartnerJourneySeed, 20260918);
    expect(canonicalPartnerJourneyNow, DateTime.utc(2026, 9, 18, 9));
    expect(canonicalPartnerJourneyLocale, 'en');

    for (final fixture in fixtures) {
      expect(fixture.ownerId, 'owner-${fixture.id}');
      expect(fixture.recipientId, 'recipient-${fixture.id}');
      expect(fixture.virtualNow, DateTime.utc(2026, 9, 18, 9));
      expect(fixture.experienceInput.ownerId, fixture.ownerId);
      expect(fixture.experienceInput.partnerId, fixture.recipientId);
      expect(fixture.experienceInput.at, fixture.virtualNow);
      expect(fixture.revocationGrant.id, 'permission-${fixture.id}');
      expect(fixture.revocationGrant.ownerId, fixture.ownerId);
      expect(fixture.revocationGrant.recipientId, fixture.recipientId);
      expect(fixture.revocationGrant.isActiveAt(fixture.virtualNow), isTrue);
      expect(fixture.notificationRequest.ownerId, fixture.ownerId);
      expect(fixture.notificationRequest.recipientId, fixture.recipientId);
      expect(fixture.notificationRequest.at, fixture.virtualNow);
      expect(
        fixture.notificationGrants.map((grant) => grant.ownerId),
        everyElement(fixture.ownerId),
      );
      expect(
        fixture.notificationGrants.map((grant) => grant.recipientId),
        everyElement(fixture.recipientId),
      );
      expect(
        fixture.keyRegistry
            .activeFor(
              ownerId: fixture.ownerId,
              recipientId: fixture.recipientId,
            )!
            .version,
        1,
      );

      final invitation = const PairingQrCodec().decode(
        fixture.invitationPayloads.single!,
        now: fixture.virtualNow,
      );
      expect(invitation.ownerId, fixture.ownerId);
      expect(invitation.recipientId, fixture.recipientId);
      expect(invitation.keyEnvelopeId, 'envelope-${fixture.id}-v1');
      expect(invitation.nonce, 'nonce-${fixture.id}');
      expect(
        invitation.expiresAt,
        DateTime.utc(2026, 9, 18, 9, 10),
      );
    }

    expect(
      rp001Fixture().sensitiveMarkers,
      <String>[
        'SYNTHETIC_SHARED_MARKER_RP_001',
        'SYNTHETIC_PRIVATE_MARKER_RP_001',
      ],
    );
    expect(
      rp002Fixture().sensitiveMarkers,
      <String>['SYNTHETIC_ABSTRACT_MARKER_RP_002'],
    );
    expect(
      rp005Fixture().sensitiveMarkers,
      <String>['SYNTHETIC_PRIVATE_MARKER_RP_005'],
    );
    expect(
      rp001Fixture()
          .experienceInput
          .grants
          .where((grant) => grant.category == 'health.energy')
          .single
          .visibility,
      RelationshipVisibility.fullyShared,
    );
    expect(
      rp002Fixture()
          .experienceInput
          .grants
          .where((grant) => grant.category == 'health.energy')
          .single
          .visibility,
      RelationshipVisibility.abstractShared,
    );
    expect(rp005Fixture().experienceInput.grants, isEmpty);
  });

  testWidgets('RP-001 pairs through the UI and reaches every partner tab', (
    tester,
  ) async {
    final harness = PartnerJourneyHarness(
      tester: tester,
      fixture: rp001Fixture(),
    );
    addTearDown(harness.cleanup);

    await harness.pump();
    await harness.pair();
    for (final tab in <String>['Now', 'Us', 'Surprise', 'Shared Health']) {
      await harness.tapTab(tab);
    }

    final observation = harness.observe(
      visibleAssertions: const <String, String>{
        'home:shared-health': 'Shared Health',
        'safety:read-only': 'Read-only',
        'visibility:fully-shared':
            'health.energy: SYNTHETIC_SHARED_MARKER_RP_001',
      },
      forbiddenMarkers: const <String, String>{
        'private-detail-hidden': 'SYNTHETIC_PRIVATE_MARKER_RP_001',
      },
    );

    expect(observation.surfaceReached, 'Shared Health');
    expect(observation.pairedAfterAction, isTrue);
    expect(observation.visibleAssertionIds, <String>[
      'home:shared-health',
      'safety:read-only',
      'visibility:fully-shared',
    ]);
    expect(
      observation.forbiddenMarkerAbsenceAssertionIds,
      <String>['private-detail-hidden'],
    );
    expect(observation.actionCount, 5);
    expect(observation.navigationCount, 4);
    expect(observation.recoveryCount, 0);
  });

  testWidgets('RP-002 keeps its abstract detail marker absent while locked', (
    tester,
  ) async {
    final harness = PartnerJourneyHarness(
      tester: tester,
      fixture: rp002Fixture(),
      deviceUnlocked: false,
    );
    addTearDown(harness.cleanup);

    await harness.pump();
    await harness.pair();
    await harness.tapTab('Shared Health');

    final observation = harness.observe(
      forbiddenMarkers: const <String, String>{
        'abstract-detail-hidden': 'SYNTHETIC_ABSTRACT_MARKER_RP_002',
      },
    );

    expect(observation.pairedAfterAction, isTrue);
    expect(
      observation.forbiddenMarkerAbsenceAssertionIds,
      <String>['abstract-detail-hidden'],
    );
  });

  testWidgets(
    'RP-005 disconnect rotates the recipient key from version one to two',
    (tester) async {
      final harness = PartnerJourneyHarness(
        tester: tester,
        fixture: rp005Fixture(),
      );
      addTearDown(harness.cleanup);

      await harness.pump();
      await harness.pair();
      await harness.tapTab('Us');
      await harness.disconnect();

      final observation = harness.observe(
        visibleAssertions: const <String, String>{
          'recovery:pairing': 'Scan pairing QR',
        },
        forbiddenMarkers: const <String, String>{
          'revoked-private-hidden': 'SYNTHETIC_PRIVATE_MARKER_RP_005',
        },
      );

      expect(observation.recipientKeyVersionBefore, 1);
      expect(observation.recipientKeyVersionAfter, 2);
      expect(observation.notificationStopped, isTrue);
      expect(observation.pairedAfterAction, isFalse);
      expect(observation.recoveryCount, 1);
    },
  );
}
