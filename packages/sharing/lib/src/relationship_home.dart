import 'couple_memory.dart';
import 'novelty.dart';
import 'read_the_room.dart';
import 'relationship_policy.dart';

enum RelationshipHomeTab { now, us, surprise, sharedHealth }

enum RelationshipHomeCardKind {
  roomAction,
  weather,
  microMoment,
  memory,
  surprise,
  sharedHealth,
}

class RelationshipHomeCard {
  const RelationshipHomeCard({
    required this.id,
    required this.tab,
    required this.kind,
    required this.reference,
    this.visibility,
    this.rawValue,
  });

  final String id;
  final RelationshipHomeTab tab;
  final RelationshipHomeCardKind kind;
  final String reference;
  final RelationshipVisibility? visibility;
  final Object? rawValue;
}

class RelationshipHomeModel {
  RelationshipHomeModel({required Iterable<RelationshipHomeCard> cards})
      : cards = List.unmodifiable(cards);

  final List<RelationshipHomeCard> cards;

  List<RelationshipHomeCard> cardsFor(RelationshipHomeTab tab) =>
      List.unmodifiable(cards.where((card) => card.tab == tab));
}

class RelationshipHomeOrchestrator {
  const RelationshipHomeOrchestrator();

  RelationshipHomeModel build({
    ReadTheRoomDecision? roomDecision,
    RelationshipWeather? weather,
    MicroMomentDecision? microMoment,
    PartnerManual? partnerManual,
    Iterable<NoveltySuggestion> surprises = const [],
    Iterable<RelationshipContextProjection<Object?>> sharedHealth = const [],
  }) {
    final cards = <RelationshipHomeCard>[];

    if (roomDecision != null) {
      cards.add(
        RelationshipHomeCard(
          id: 'now-room-${roomDecision.signalId}',
          tab: RelationshipHomeTab.now,
          kind: RelationshipHomeCardKind.roomAction,
          reference: roomDecision.action.name,
        ),
      );
    }

    if (weather != null && weather.kind != RelationshipWeatherKind.unknown) {
      cards.add(
        RelationshipHomeCard(
          id: 'now-weather-${weather.kind.name}',
          tab: RelationshipHomeTab.now,
          kind: RelationshipHomeCardKind.weather,
          reference: weather.kind.name,
        ),
      );
    }

    if (microMoment?.shouldSurface == true && microMoment!.candidate != null) {
      final candidate = microMoment.candidate!;
      cards.add(
        RelationshipHomeCard(
          id: 'now-micro-${candidate.id}',
          tab: RelationshipHomeTab.now,
          kind: RelationshipHomeCardKind.microMoment,
          reference: candidate.action.name,
        ),
      );
    }

    if (partnerManual != null) {
      for (final entry in partnerManual.entries) {
        if (!_partnerVisible(entry.visibility)) continue;
        cards.add(
          RelationshipHomeCard(
            id: 'us-memory-${entry.id}',
            tab: RelationshipHomeTab.us,
            kind: RelationshipHomeCardKind.memory,
            reference: '${entry.kind.name}:${entry.key}',
            visibility: entry.visibility,
            rawValue: entry.exposesRawValue ? entry.value : null,
          ),
        );
      }
    }

    final surpriseList = surprises.toList()
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        if (score != 0) return score;
        return a.candidateId.compareTo(b.candidateId);
      });
    for (final suggestion in surpriseList) {
      cards.add(
        RelationshipHomeCard(
          id: 'surprise-${suggestion.candidateId}',
          tab: RelationshipHomeTab.surprise,
          kind: RelationshipHomeCardKind.surprise,
          reference: suggestion.category,
        ),
      );
    }

    final healthList = sharedHealth
        .where((projection) =>
            projection.capability == RelationshipCapability.view &&
            _partnerVisible(projection.visibility))
        .toList()
      ..sort((a, b) {
        final category = a.category.compareTo(b.category);
        if (category != 0) return category;
        return a.ownerId.compareTo(b.ownerId);
      });
    for (final projection in healthList) {
      cards.add(
        RelationshipHomeCard(
          id: 'health-${projection.ownerId}-${projection.category}',
          tab: RelationshipHomeTab.sharedHealth,
          kind: RelationshipHomeCardKind.sharedHealth,
          reference: projection.category,
          visibility: projection.visibility,
          rawValue: projection.exposesRawValue ? projection.value : null,
        ),
      );
    }

    cards.sort((a, b) {
      final tab = a.tab.index.compareTo(b.tab.index);
      if (tab != 0) return tab;
      final kind = a.kind.index.compareTo(b.kind.index);
      if (kind != 0) return kind;
      return a.id.compareTo(b.id);
    });

    return RelationshipHomeModel(cards: cards);
  }
}

bool _partnerVisible(RelationshipVisibility visibility) =>
    visibility == RelationshipVisibility.abstractShared ||
    visibility == RelationshipVisibility.fullyShared;
