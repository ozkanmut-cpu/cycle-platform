import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 17);

  RelationshipCategoryGrant grant(
    String category,
    RelationshipCapability capability,
    RelationshipVisibility visibility,
  ) =>
      RelationshipCategoryGrant(
        id: 'g-$category-${capability.name}',
        ownerId: 'a',
        recipientId: 'b',
        category: category,
        capabilities: {capability},
        visibility: visibility,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

  test('coordinator builds all partner home surfaces from authorized inputs',
      () {
    final input = PartnerExperienceInput(
      ownerId: 'a',
      partnerId: 'b',
      at: now,
      roomSignals: [
        RoomSignal(
          id: 'space',
          ownerId: 'a',
          partnerId: 'b',
          kind: RoomSignalKind.needsSpace,
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
      ],
      microMoments: const [
        MicroMomentCandidate(
          id: 'check',
          action: RoomActionKind.checkIn,
          informationValue: 0.9,
          userBurden: 0.1,
        ),
      ],
      memories: [
        CoupleMemoryItem(
          id: 'nick',
          ownerId: 'a',
          partnerId: 'b',
          kind: CoupleMemoryKind.nickname,
          key: 'preferred',
          value: 'Sunshine',
          createdAt: now.subtract(const Duration(days: 1)),
          visibility: RelationshipVisibility.fullyShared,
        ),
      ],
      sharedHealthEntries: [
        CoupleContextEntry<Object?>(
          ownerId: 'a',
          category: 'health.energy',
          observedAt: now.subtract(const Duration(minutes: 10)),
          visibility: RelationshipVisibility.fullyShared,
          value: 'low',
        ),
      ],
      coupleDna: CoupleDna(
        ownerId: 'a',
        partnerId: 'b',
        preferredTags: const {'quiet'},
        dontSuggestTags: const {},
        dontSuggestCandidateIds: const {},
      ),
      noveltyCandidates: [
        NoveltyCandidate(
          id: 'tea',
          category: 'date',
          title: 'Tea together',
          tags: const {'quiet'},
          cost: 0,
          durationMinutes: 20,
          energy: NoveltyEnergy.low,
          setting: NoveltySetting.home,
        ),
      ],
      grants: [
        grant(
          'relationship.room.needsSpace',
          RelationshipCapability.relationshipIntelligence,
          RelationshipVisibility.engineOnly,
        ),
        grant(
          'relationship.memory.nickname.preferred',
          RelationshipCapability.view,
          RelationshipVisibility.fullyShared,
        ),
        grant(
          'health.energy',
          RelationshipCapability.view,
          RelationshipVisibility.fullyShared,
        ),
        grant(
          'relationship.novelty.date',
          RelationshipCapability.relationshipIntelligence,
          RelationshipVisibility.engineOnly,
        ),
      ],
    );

    final model = const PartnerExperienceCoordinator().build(input);
    expect(model.cardsFor(RelationshipHomeTab.now), hasLength(3));
    expect(model.cardsFor(RelationshipHomeTab.us).single.rawValue, 'Sunshine');
    expect(
      model.cardsFor(RelationshipHomeTab.sharedHealth).single.rawValue,
      'low',
    );
    expect(model.cardsFor(RelationshipHomeTab.surprise), hasLength(1));
  });

  test('engine-only health context never crosses presentation boundary', () {
    final model = const PartnerExperienceCoordinator().build(
      PartnerExperienceInput(
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
            id: 'engine-health',
            ownerId: 'a',
            recipientId: 'b',
            category: 'health.sleep',
            capabilities: {
              RelationshipCapability.relationshipIntelligence,
            },
            visibility: RelationshipVisibility.engineOnly,
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
      ),
    );
    expect(model.cardsFor(RelationshipHomeTab.sharedHealth), isEmpty);
  });

  test('view grant does not make room signal usable by intelligence', () {
    final model = const PartnerExperienceCoordinator().build(
      PartnerExperienceInput(
        ownerId: 'a',
        partnerId: 'b',
        at: now,
        roomSignals: [
          RoomSignal(
            id: 'fun',
            ownerId: 'a',
            partnerId: 'b',
            kind: RoomSignalKind.wantsFun,
            createdAt: now,
          ),
        ],
        grants: [
          RelationshipCategoryGrant(
            id: 'view-room',
            ownerId: 'a',
            recipientId: 'b',
            category: 'relationship.room.wantsFun',
            capabilities: {RelationshipCapability.view},
            visibility: RelationshipVisibility.fullyShared,
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
      ),
    );
    expect(model.cardsFor(RelationshipHomeTab.now), isEmpty);
  });

  test('wrong partner scope fails closed across coordinator', () {
    expect(
      () => const PartnerExperienceCoordinator().build(
        PartnerExperienceInput(
          ownerId: 'a',
          partnerId: 'a',
          at: now,
          grants: const [],
        ),
      ),
      throwsA(isA<RelationshipPolicyException>()),
    );
  });
}
