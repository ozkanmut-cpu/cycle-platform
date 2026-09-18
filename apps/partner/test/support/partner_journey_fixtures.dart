import 'package:cycle_permissions/cycle_permissions.dart';
import 'package:cycle_sharing/cycle_sharing.dart';

const int canonicalPartnerJourneySeed = 20260918;
final DateTime canonicalPartnerJourneyNow = DateTime.utc(2026, 9, 18, 9);
const String canonicalPartnerJourneyLocale = 'en';

class PartnerJourneyFixture {
  const PartnerJourneyFixture({
    required this.id,
    required this.ownerId,
    required this.recipientId,
    required this.virtualNow,
    required this.experienceInput,
    required this.revocationGrant,
    required this.notificationRequest,
    required this.notificationGrants,
    required this.invitationPayloads,
    required this.keyRegistry,
    required this.sensitiveMarkers,
  });

  final String id;
  final String ownerId;
  final String recipientId;
  final DateTime virtualNow;
  final PartnerExperienceInput experienceInput;
  final PermissionGrant revocationGrant;
  final RelationshipNotificationRequest notificationRequest;
  final List<RelationshipCategoryGrant> notificationGrants;
  final List<String?> invitationPayloads;
  final RecipientKeyRegistry keyRegistry;
  final List<String> sensitiveMarkers;
}

PartnerJourneyFixture rp001Fixture() => _fixture(
      id: 'RP-001',
      healthVisibility: RelationshipVisibility.fullyShared,
      healthMarker: 'SYNTHETIC_SHARED_MARKER_RP_001',
      sensitiveMarkers: const <String>[
        'SYNTHETIC_SHARED_MARKER_RP_001',
        'SYNTHETIC_PRIVATE_MARKER_RP_001',
      ],
      includeHealthGrant: true,
    );

PartnerJourneyFixture rp002Fixture() => _fixture(
      id: 'RP-002',
      healthVisibility: RelationshipVisibility.abstractShared,
      healthMarker: 'SYNTHETIC_ABSTRACT_MARKER_RP_002',
      sensitiveMarkers: const <String>['SYNTHETIC_ABSTRACT_MARKER_RP_002'],
      includeHealthGrant: true,
    );

PartnerJourneyFixture rp005Fixture() => _fixture(
      id: 'RP-005',
      healthVisibility: RelationshipVisibility.private,
      healthMarker: 'SYNTHETIC_PRIVATE_MARKER_RP_005',
      sensitiveMarkers: const <String>['SYNTHETIC_PRIVATE_MARKER_RP_005'],
      includeHealthGrant: false,
    );

PartnerJourneyFixture _fixture({
  required String id,
  required RelationshipVisibility healthVisibility,
  required String healthMarker,
  required List<String> sensitiveMarkers,
  required bool includeHealthGrant,
}) {
  final ownerId = 'owner-$id';
  final recipientId = 'recipient-$id';
  final now = canonicalPartnerJourneyNow;
  final createdAt = now.subtract(const Duration(days: 1));
  final grants = <RelationshipCategoryGrant>[
    if (includeHealthGrant)
      RelationshipCategoryGrant(
        id: 'view-health-energy-$id',
        ownerId: ownerId,
        recipientId: recipientId,
        category: 'health.energy',
        capabilities: const <RelationshipCapability>{
          RelationshipCapability.view,
        },
        visibility: healthVisibility,
        createdAt: createdAt,
      ),
    RelationshipCategoryGrant(
      id: 'notify-cycle-$id',
      ownerId: ownerId,
      recipientId: recipientId,
      category: 'cycle',
      capabilities: const <RelationshipCapability>{
        RelationshipCapability.notify,
      },
      visibility: RelationshipVisibility.private,
      createdAt: createdAt,
    ),
  ];
  final invitation = PairingInvitation(
    ownerId: ownerId,
    recipientId: recipientId,
    keyEnvelopeId: 'envelope-$id-v1',
    nonce: 'nonce-$id',
    expiresAt: now.add(const Duration(minutes: 10)),
  );

  return PartnerJourneyFixture(
    id: id,
    ownerId: ownerId,
    recipientId: recipientId,
    virtualNow: now,
    experienceInput: PartnerExperienceInput(
      ownerId: ownerId,
      partnerId: recipientId,
      at: now,
      grants: List<RelationshipCategoryGrant>.unmodifiable(grants),
      sharedHealthEntries: includeHealthGrant
          ? <CoupleContextEntry<Object?>>[
              CoupleContextEntry<Object?>(
                ownerId: ownerId,
                category: 'health.energy',
                observedAt: now,
                visibility: healthVisibility,
                value: healthMarker,
              ),
            ]
          : const <CoupleContextEntry<Object?>>[],
    ),
    revocationGrant: PermissionGrant(
      id: 'permission-$id',
      ownerId: ownerId,
      recipientId: recipientId,
      recipientKind: RecipientKind.partner,
      actions: const <PermissionAction>{
        PermissionAction.view,
        PermissionAction.notify,
      },
      scope: const PermissionScope(
        categories: <String>{'cycle', 'health.energy'},
      ),
      createdAt: createdAt,
    ),
    notificationRequest: RelationshipNotificationRequest(
      ownerId: ownerId,
      recipientId: recipientId,
      category: 'cycle',
      categoryLabel: 'Cycle',
      detail: 'SYNTHETIC_PRIVATE_MARKER_${id.replaceAll('-', '_')}',
      kind: RelationshipNotificationKind.relationship,
      at: now,
    ),
    notificationGrants: List<RelationshipCategoryGrant>.unmodifiable(
      grants.where((grant) => grant.category == 'cycle'),
    ),
    invitationPayloads: List<String?>.unmodifiable(<String?>[
      const PairingQrCodec().encode(invitation),
    ]),
    keyRegistry: RecipientKeyRegistry(
      initial: <RecipientKeyState>[
        RecipientKeyState(
          ownerId: ownerId,
          recipientId: recipientId,
          keyEnvelopeId: 'envelope-$id-v1',
          version: 1,
          createdAt: createdAt,
        ),
      ],
    ),
    sensitiveMarkers: List<String>.unmodifiable(sensitiveMarkers),
  );
}
