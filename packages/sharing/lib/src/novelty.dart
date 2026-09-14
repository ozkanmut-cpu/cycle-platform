import 'relationship_policy.dart';

enum NoveltyEnergy { low, medium, high }

enum NoveltySetting { home, out, either }

class CoupleDna {
  CoupleDna({
    required this.ownerId,
    required this.partnerId,
    required Set<String> preferredTags,
    required Set<String> dontSuggestTags,
    required Set<String> dontSuggestCandidateIds,
    this.maxBudget,
    this.maxDurationMinutes,
    this.maxEnergy = NoveltyEnergy.high,
    this.setting = NoveltySetting.either,
    this.allowIntimacySuggestions = false,
  })  : preferredTags = Set.unmodifiable(_clean(preferredTags)),
        dontSuggestTags = Set.unmodifiable(_clean(dontSuggestTags)),
        dontSuggestCandidateIds =
            Set.unmodifiable(_clean(dontSuggestCandidateIds)) {
    _requireNoveltyText(ownerId, 'ownerId');
    _requireNoveltyText(partnerId, 'partnerId');
    if (ownerId == partnerId) {
      throw const RelationshipPolicyException(
        'couple DNA owner and partner must differ',
      );
    }
    if (maxBudget != null && maxBudget! < 0) {
      throw const RelationshipPolicyException('maxBudget must not be negative');
    }
    if (maxDurationMinutes != null && maxDurationMinutes! <= 0) {
      throw const RelationshipPolicyException(
        'maxDurationMinutes must be positive',
      );
    }
  }

  final String ownerId;
  final String partnerId;
  final Set<String> preferredTags;
  final Set<String> dontSuggestTags;
  final Set<String> dontSuggestCandidateIds;
  final int? maxBudget;
  final int? maxDurationMinutes;
  final NoveltyEnergy maxEnergy;
  final NoveltySetting setting;
  final bool allowIntimacySuggestions;
}

class NoveltyCandidate {
  NoveltyCandidate({
    required this.id,
    required this.category,
    required this.title,
    required Set<String> tags,
    required this.cost,
    required this.durationMinutes,
    required this.energy,
    required this.setting,
    this.requiresIntimacy = false,
  }) : tags = Set.unmodifiable(_clean(tags)) {
    _requireNoveltyText(id, 'id');
    _requireNoveltyText(category, 'category');
    _requireNoveltyText(title, 'title');
    if (cost < 0) {
      throw const RelationshipPolicyException(
          'candidate cost must not be negative');
    }
    if (durationMinutes <= 0) {
      throw const RelationshipPolicyException(
        'candidate duration must be positive',
      );
    }
  }

  final String id;
  final String category;
  final String title;
  final Set<String> tags;
  final int cost;
  final int durationMinutes;
  final NoveltyEnergy energy;
  final NoveltySetting setting;
  final bool requiresIntimacy;
}

class NoveltyHistoryEntry {
  const NoveltyHistoryEntry({
    required this.candidateId,
    required this.usedAt,
  });

  final String candidateId;
  final DateTime usedAt;
}

class NoveltySuggestion {
  const NoveltySuggestion({
    required this.candidateId,
    required this.category,
    required this.title,
    required this.score,
    required this.reasonTags,
  });

  final String candidateId;
  final String category;
  final String title;
  final int score;
  final List<String> reasonTags;
}

class NoveltyEngine {
  const NoveltyEngine({
    this.firewall = const RelationshipPermissionFirewall(),
    this.repeatCooldown = const Duration(days: 30),
  });

  final RelationshipPermissionFirewall firewall;
  final Duration repeatCooldown;

  List<NoveltySuggestion> surpriseMeSafely({
    required String ownerId,
    required String recipientId,
    required DateTime at,
    required CoupleDna dna,
    required Iterable<NoveltyCandidate> candidates,
    required Iterable<NoveltyHistoryEntry> history,
    required Iterable<RelationshipCategoryGrant> grants,
    int limit = 3,
  }) {
    if (ownerId != dna.ownerId || recipientId != dna.partnerId || limit <= 0) {
      return const [];
    }

    final recentIds = history
        .where((entry) =>
            !entry.usedAt.isAfter(at) &&
            at.difference(entry.usedAt) < repeatCooldown)
        .map((entry) => entry.candidateId)
        .toSet();

    final ranked = <_RankedNovelty>[];
    for (final candidate in candidates) {
      if (!_passesHardConstraints(candidate, dna, recentIds)) continue;
      if (!_purposeAllowed(
          ownerId, recipientId, candidate.category, at, grants)) {
        continue;
      }
      if (candidate.requiresIntimacy &&
          (!_intimacyAllowed(
                  ownerId, recipientId, candidate.category, at, grants) ||
              !dna.allowIntimacySuggestions)) {
        continue;
      }

      final reasonTags = candidate.tags.intersection(dna.preferredTags).toList()
        ..sort();
      final score = 100 + (reasonTags.length * 10) - candidate.energy.index;
      ranked.add(_RankedNovelty(candidate, score, reasonTags));
    }

    ranked.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return a.candidate.id.compareTo(b.candidate.id);
    });

    return List.unmodifiable(
      ranked.take(limit).map(
            (entry) => NoveltySuggestion(
              candidateId: entry.candidate.id,
              category: entry.candidate.category,
              title: entry.candidate.title,
              score: entry.score,
              reasonTags: List.unmodifiable(entry.reasonTags),
            ),
          ),
    );
  }

  bool _passesHardConstraints(
    NoveltyCandidate candidate,
    CoupleDna dna,
    Set<String> recentIds,
  ) {
    if (dna.dontSuggestCandidateIds.contains(candidate.id)) return false;
    if (candidate.tags.intersection(dna.dontSuggestTags).isNotEmpty)
      return false;
    if (recentIds.contains(candidate.id)) return false;
    if (dna.maxBudget != null && candidate.cost > dna.maxBudget!) return false;
    if (dna.maxDurationMinutes != null &&
        candidate.durationMinutes > dna.maxDurationMinutes!) {
      return false;
    }
    if (candidate.energy.index > dna.maxEnergy.index) return false;
    if (dna.setting != NoveltySetting.either &&
        candidate.setting != NoveltySetting.either &&
        candidate.setting != dna.setting) {
      return false;
    }
    return true;
  }

  bool _purposeAllowed(
    String ownerId,
    String recipientId,
    String category,
    DateTime at,
    Iterable<RelationshipCategoryGrant> grants,
  ) =>
      firewall
          .evaluate(
            request: RelationshipAccessRequest(
              ownerId: ownerId,
              recipientId: recipientId,
              category: 'relationship.novelty.$category',
              capability: RelationshipCapability.relationshipIntelligence,
              at: at,
            ),
            grants: grants,
          )
          .allowed;

  bool _intimacyAllowed(
    String ownerId,
    String recipientId,
    String category,
    DateTime at,
    Iterable<RelationshipCategoryGrant> grants,
  ) =>
      firewall
          .evaluate(
            request: RelationshipAccessRequest(
              ownerId: ownerId,
              recipientId: recipientId,
              category: 'relationship.intimacy.$category',
              capability: RelationshipCapability.intimacy,
              at: at,
            ),
            grants: grants,
          )
          .allowed;
}

class _RankedNovelty {
  const _RankedNovelty(this.candidate, this.score, this.reasonTags);
  final NoveltyCandidate candidate;
  final int score;
  final List<String> reasonTags;
}

Set<String> _clean(Iterable<String> values) => values
    .map((value) => value.trim().toLowerCase())
    .where((value) => value.isNotEmpty)
    .toSet();

void _requireNoveltyText(String value, String field) {
  if (value.trim().isEmpty) {
    throw RelationshipPolicyException('$field must not be blank');
  }
}
