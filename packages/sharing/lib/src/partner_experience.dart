import 'couple_context.dart';
import 'couple_memory.dart';
import 'novelty.dart';
import 'read_the_room.dart';
import 'relationship_home.dart';
import 'relationship_policy.dart';

class PartnerExperienceInput {
  const PartnerExperienceInput({
    required this.ownerId,
    required this.partnerId,
    required this.at,
    required this.grants,
    this.roomSignals = const [],
    this.microMoments = const [],
    this.userInteractedRecently = false,
    this.memories = const [],
    this.sharedHealthEntries = const [],
    this.coupleDna,
    this.noveltyCandidates = const [],
    this.noveltyHistory = const [],
  });

  final String ownerId;
  final String partnerId;
  final DateTime at;
  final Iterable<RelationshipCategoryGrant> grants;
  final Iterable<RoomSignal> roomSignals;
  final Iterable<MicroMomentCandidate> microMoments;
  final bool userInteractedRecently;
  final Iterable<CoupleMemoryItem> memories;
  final Iterable<CoupleContextEntry<Object?>> sharedHealthEntries;
  final CoupleDna? coupleDna;
  final Iterable<NoveltyCandidate> noveltyCandidates;
  final Iterable<NoveltyHistoryEntry> noveltyHistory;
}

class PartnerExperienceCoordinator {
  const PartnerExperienceCoordinator({
    this.situationEngine = const RelationshipSituationEngine(),
    this.memoryEngine = const CoupleMemoryEngine(),
    this.contextEngine = const CoupleContextEngine(),
    this.noveltyEngine = const NoveltyEngine(),
    this.homeOrchestrator = const RelationshipHomeOrchestrator(),
  });

  final RelationshipSituationEngine situationEngine;
  final CoupleMemoryEngine memoryEngine;
  final CoupleContextEngine contextEngine;
  final NoveltyEngine noveltyEngine;
  final RelationshipHomeOrchestrator homeOrchestrator;

  RelationshipHomeModel build(PartnerExperienceInput input) {
    _validateScope(input.ownerId, input.partnerId);

    final roomDecision = situationEngine.readTheRoom(
      ownerId: input.ownerId,
      partnerId: input.partnerId,
      at: input.at,
      signals: input.roomSignals,
      grants: input.grants,
    );
    final weather = situationEngine.weather(
      ownerId: input.ownerId,
      partnerId: input.partnerId,
      at: input.at,
      signals: input.roomSignals,
      grants: input.grants,
    );
    final microMoment = situationEngine.chooseMicroMoment(
      userInteractedRecently: input.userInteractedRecently,
      candidates: input.microMoments,
    );

    final partnerManual = memoryEngine.buildPartnerManual(
      ownerId: input.ownerId,
      partnerId: input.partnerId,
      capability: RelationshipCapability.view,
      at: input.at,
      items: input.memories,
      grants: input.grants,
    );

    final sharedHealth = contextEngine.build<Object?>(
      ownerId: input.ownerId,
      recipientId: input.partnerId,
      capability: RelationshipCapability.view,
      at: input.at,
      entries: input.sharedHealthEntries,
      grants: input.grants,
    );

    final surprises = input.coupleDna == null
        ? const <NoveltySuggestion>[]
        : noveltyEngine.surpriseMeSafely(
            ownerId: input.ownerId,
            recipientId: input.partnerId,
            at: input.at,
            dna: input.coupleDna!,
            candidates: input.noveltyCandidates,
            history: input.noveltyHistory,
            grants: input.grants,
          );

    return homeOrchestrator.build(
      roomDecision: roomDecision,
      weather: weather,
      microMoment: microMoment,
      partnerManual: partnerManual,
      surprises: surprises,
      sharedHealth: sharedHealth.projections,
    );
  }
}

void _validateScope(String ownerId, String partnerId) {
  if (ownerId.trim().isEmpty ||
      partnerId.trim().isEmpty ||
      ownerId == partnerId) {
    throw const RelationshipPolicyException('invalid partner experience scope');
  }
}
