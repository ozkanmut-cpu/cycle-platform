import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  test('now combines room weather and surfaced micro moment', () {
    final model = const RelationshipHomeOrchestrator().build(
      roomDecision: const ReadTheRoomDecision(
        signalId: 'space',
        action: RoomActionKind.giveSpace,
        kind: RoomSignalKind.needsSpace,
      ),
      weather: const RelationshipWeather(
        kind: RelationshipWeatherKind.quiet,
        basedOnSignalIds: ['space'],
      ),
      microMoment: const MicroMomentDecision(
        shouldSurface: true,
        reason: 'meaningful_low_burden_moment',
        candidate: MicroMomentCandidate(
          id: 'check',
          action: RoomActionKind.checkIn,
          informationValue: 0.9,
          userBurden: 0.1,
        ),
      ),
    );
    expect(model.cardsFor(RelationshipHomeTab.now), hasLength(3));
  });

  test('zero-log suppressed micro moment is absent from home', () {
    final model = const RelationshipHomeOrchestrator().build(
      microMoment: const MicroMomentDecision(
        shouldSurface: false,
        reason: 'low_information_value',
      ),
    );
    expect(model.cardsFor(RelationshipHomeTab.now), isEmpty);
  });

  test('engine-only memory never appears in partner home', () {
    final manual = PartnerManual(
      ownerId: 'a',
      partnerId: 'b',
      entries: const [
        CoupleMemoryProjection(
          id: 'secret',
          ownerId: 'a',
          recipientId: 'b',
          kind: CoupleMemoryKind.partnerManual,
          key: 'comfort',
          capability: RelationshipCapability.relationshipIntelligence,
          visibility: RelationshipVisibility.engineOnly,
          value: null,
        ),
      ],
    );
    final model = const RelationshipHomeOrchestrator().build(
      partnerManual: manual,
    );
    expect(model.cardsFor(RelationshipHomeTab.us), isEmpty);
  });

  test('abstract memory may surface without raw value', () {
    final manual = PartnerManual(
      ownerId: 'a',
      partnerId: 'b',
      entries: const [
        CoupleMemoryProjection(
          id: 'boundary',
          ownerId: 'a',
          recipientId: 'b',
          kind: CoupleMemoryKind.boundary,
          key: 'teasing',
          capability: RelationshipCapability.view,
          visibility: RelationshipVisibility.abstractShared,
          value: null,
        ),
      ],
    );
    final card = const RelationshipHomeOrchestrator()
        .build(partnerManual: manual)
        .cardsFor(RelationshipHomeTab.us)
        .single;
    expect(card.rawValue, isNull);
  });

  test('shared health requires VIEW projection and partner visibility', () {
    final model = const RelationshipHomeOrchestrator().build(
      sharedHealth: const [
        RelationshipContextProjection<Object?>(
          ownerId: 'a',
          recipientId: 'b',
          category: 'health.sleep',
          capability: RelationshipCapability.relationshipIntelligence,
          visibility: RelationshipVisibility.engineOnly,
          value: null,
        ),
        RelationshipContextProjection<Object?>(
          ownerId: 'a',
          recipientId: 'b',
          category: 'health.energy',
          capability: RelationshipCapability.view,
          visibility: RelationshipVisibility.abstractShared,
          value: null,
        ),
      ],
    );
    final cards = model.cardsFor(RelationshipHomeTab.sharedHealth);
    expect(cards, hasLength(1));
    expect(cards.single.reference, 'health.energy');
    expect(cards.single.rawValue, isNull);
  });

  test('fully shared health may expose raw value', () {
    final card = const RelationshipHomeOrchestrator()
        .build(
          sharedHealth: const [
            RelationshipContextProjection<Object?>(
              ownerId: 'a',
              recipientId: 'b',
              category: 'health.energy',
              capability: RelationshipCapability.view,
              visibility: RelationshipVisibility.fullyShared,
              value: 'low',
            ),
          ],
        )
        .cardsFor(RelationshipHomeTab.sharedHealth)
        .single;
    expect(card.rawValue, 'low');
  });

  test('surprises are sorted deterministically by score then id', () {
    final cards = const RelationshipHomeOrchestrator().build(
      surprises: const [
        NoveltySuggestion(
          candidateId: 'b',
          category: 'date',
          title: 'B',
          score: 100,
          reasonTags: [],
        ),
        NoveltySuggestion(
          candidateId: 'a',
          category: 'date',
          title: 'A',
          score: 100,
          reasonTags: [],
        ),
      ],
    ).cardsFor(RelationshipHomeTab.surprise);
    expect(cards.map((e) => e.id), ['surprise-a', 'surprise-b']);
  });
}
