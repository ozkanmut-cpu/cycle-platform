import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 13);

  CoupleDna dna({
    Set<String> preferred = const {'food', 'music'},
    Set<String> dontTags = const {},
    Set<String> dontIds = const {},
    int? budget = 500,
    int? duration = 180,
    NoveltyEnergy energy = NoveltyEnergy.medium,
    NoveltySetting setting = NoveltySetting.either,
    bool intimacy = false,
  }) =>
      CoupleDna(
        ownerId: 'a',
        partnerId: 'b',
        preferredTags: preferred,
        dontSuggestTags: dontTags,
        dontSuggestCandidateIds: dontIds,
        maxBudget: budget,
        maxDurationMinutes: duration,
        maxEnergy: energy,
        setting: setting,
        allowIntimacySuggestions: intimacy,
      );

  NoveltyCandidate candidate({
    required String id,
    Set<String> tags = const {'food'},
    int cost = 100,
    int duration = 60,
    NoveltyEnergy energy = NoveltyEnergy.low,
    NoveltySetting setting = NoveltySetting.home,
    bool intimacy = false,
  }) =>
      NoveltyCandidate(
        id: id,
        category: 'date',
        title: 'Idea $id',
        tags: tags,
        cost: cost,
        durationMinutes: duration,
        energy: energy,
        setting: setting,
        requiresIntimacy: intimacy,
      );

  RelationshipCategoryGrant grant(RelationshipCapability capability) =>
      RelationshipCategoryGrant(
        id: 'g-${capability.name}',
        ownerId: 'a',
        recipientId: 'b',
        category: capability == RelationshipCapability.intimacy
            ? 'relationship.intimacy.date'
            : 'relationship.novelty.date',
        capabilities: {capability},
        visibility: RelationshipVisibility.engineOnly,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

  test('dont-suggest tag is a hard filter', () {
    final result = const NoveltyEngine().surpriseMeSafely(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      dna: dna(dontTags: {'food'}),
      candidates: [candidate(id: 'x')],
      history: const [],
      grants: [grant(RelationshipCapability.relationshipIntelligence)],
    );
    expect(result, isEmpty);
  });

  test('budget duration energy and setting are hard constraints', () {
    final result = const NoveltyEngine().surpriseMeSafely(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      dna: dna(
          budget: 50,
          duration: 30,
          energy: NoveltyEnergy.low,
          setting: NoveltySetting.home),
      candidates: [
        candidate(
            id: 'x',
            cost: 100,
            duration: 60,
            energy: NoveltyEnergy.medium,
            setting: NoveltySetting.out)
      ],
      history: const [],
      grants: [grant(RelationshipCapability.relationshipIntelligence)],
    );
    expect(result, isEmpty);
  });

  test('recently used candidate is suppressed by cooldown', () {
    final result = const NoveltyEngine().surpriseMeSafely(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      dna: dna(),
      candidates: [candidate(id: 'x')],
      history: [
        NoveltyHistoryEntry(
            candidateId: 'x', usedAt: now.subtract(const Duration(days: 2)))
      ],
      grants: [grant(RelationshipCapability.relationshipIntelligence)],
    );
    expect(result, isEmpty);
  });

  test('relationship intelligence permission is required', () {
    final result = const NoveltyEngine().surpriseMeSafely(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      dna: dna(),
      candidates: [candidate(id: 'x')],
      history: const [],
      grants: const [],
    );
    expect(result, isEmpty);
  });

  test('intimacy idea requires both explicit DNA opt-in and intimacy grant',
      () {
    final item = candidate(id: 'x', intimacy: true);
    final relationshipGrant =
        grant(RelationshipCapability.relationshipIntelligence);
    final blocked = const NoveltyEngine().surpriseMeSafely(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      dna: dna(intimacy: false),
      candidates: [item],
      history: const [],
      grants: [relationshipGrant, grant(RelationshipCapability.intimacy)],
    );
    expect(blocked, isEmpty);
    final allowed = const NoveltyEngine().surpriseMeSafely(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      dna: dna(intimacy: true),
      candidates: [item],
      history: const [],
      grants: [relationshipGrant, grant(RelationshipCapability.intimacy)],
    );
    expect(allowed, hasLength(1));
  });

  test('preferred tags rank matching candidate first deterministically', () {
    final result = const NoveltyEngine().surpriseMeSafely(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      dna: dna(preferred: {'music'}),
      candidates: [
        candidate(id: 'b', tags: {'food'}),
        candidate(id: 'a', tags: {'music'})
      ],
      history: const [],
      grants: [grant(RelationshipCapability.relationshipIntelligence)],
    );
    expect(result.first.candidateId, 'a');
    expect(result.first.reasonTags, ['music']);
  });

  test('no qualifying idea returns empty instead of inventing a fallback', () {
    final result = const NoveltyEngine().surpriseMeSafely(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      dna: dna(dontIds: {'x'}),
      candidates: [candidate(id: 'x')],
      history: const [],
      grants: [grant(RelationshipCapability.relationshipIntelligence)],
    );
    expect(result, isEmpty);
  });
}
