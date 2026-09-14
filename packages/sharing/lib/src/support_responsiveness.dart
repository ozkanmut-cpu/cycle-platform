import 'relationship_signals.dart';

enum SupportActionKind {
  listen,
  checkIn,
  practicalHelp,
  quietPresence,
  giveSpace,
  affection,
  comfort,
  companionship,
  distraction,
  encouragement,
  celebration,
  custom,
}

enum SupportPreferenceOrigin {
  explicitCurrent,
  explicitStanding,
  confirmedLearned,
  observedCandidate,
  generic,
}

enum ResponsivenessFeedback {
  worked,
  moreLikeThis,
  neutral,
  unsure,
  neverSuggest
}

class SupportPreference {
  SupportPreference({
    required this.id,
    required this.ownerId,
    required this.action,
    required this.origin,
    required this.createdAt,
    this.signalKind,
    this.customActionKey,
    this.expiresAt,
    this.revokedAt,
    this.priority = 0,
  }) {
    if (id.trim().isEmpty || ownerId.trim().isEmpty) {
      throw ArgumentError('support preference id/ownerId must not be blank');
    }
    if (action == SupportActionKind.custom &&
        (customActionKey == null || customActionKey!.trim().isEmpty)) {
      throw ArgumentError('custom support action requires customActionKey');
    }
    if (expiresAt != null && !expiresAt!.isAfter(createdAt)) {
      throw ArgumentError('expiresAt must be after createdAt');
    }
    if (revokedAt != null && revokedAt!.isBefore(createdAt)) {
      throw ArgumentError('revokedAt must not precede createdAt');
    }
  }

  final String id;
  final String ownerId;
  final RelationshipSignalKind? signalKind;
  final SupportActionKind action;
  final String? customActionKey;
  final SupportPreferenceOrigin origin;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final int priority;

  bool isActiveAt(DateTime at) {
    if (at.isBefore(createdAt)) return false;
    if (revokedAt != null && !at.isBefore(revokedAt!)) return false;
    return expiresAt == null || at.isBefore(expiresAt!);
  }

  String get logicalAction => action == SupportActionKind.custom
      ? 'custom:${customActionKey!.trim()}'
      : action.name;
}

class ResponsivenessObservation {
  ResponsivenessObservation({
    required this.id,
    required this.ownerId,
    required this.action,
    required this.feedback,
    required this.observedAt,
    this.signalKind,
    this.customActionKey,
  }) {
    if (id.trim().isEmpty || ownerId.trim().isEmpty) {
      throw ArgumentError('responsiveness observation scope must not be blank');
    }
    if (action == SupportActionKind.custom &&
        (customActionKey == null || customActionKey!.trim().isEmpty)) {
      throw ArgumentError('custom observation requires customActionKey');
    }
  }

  final String id;
  final String ownerId;
  final RelationshipSignalKind? signalKind;
  final SupportActionKind action;
  final String? customActionKey;
  final ResponsivenessFeedback feedback;
  final DateTime observedAt;

  String get logicalAction => action == SupportActionKind.custom
      ? 'custom:${customActionKey!.trim()}'
      : action.name;
}

class ResponsivenessCandidate {
  const ResponsivenessCandidate({
    required this.ownerId,
    required this.signalKind,
    required this.action,
    required this.score,
    required this.evidenceIds,
  });

  final String ownerId;
  final RelationshipSignalKind? signalKind;
  final SupportActionKind action;
  final int score;
  final List<String> evidenceIds;
}

class ResponsivenessEngine {
  const ResponsivenessEngine();

  List<ResponsivenessCandidate> deriveCandidates({
    required String ownerId,
    required Iterable<ResponsivenessObservation> observations,
  }) {
    final scoped = observations.where((o) => o.ownerId == ownerId).toList();
    final buckets = <String, List<ResponsivenessObservation>>{};
    for (final observation in scoped) {
      final key =
          '${observation.signalKind?.name ?? '*'}|${observation.logicalAction}';
      buckets.putIfAbsent(key, () => []).add(observation);
    }

    final result = <ResponsivenessCandidate>[];
    final keys = buckets.keys.toList()..sort();
    for (final key in keys) {
      final values = buckets[key]!..sort((a, b) => a.id.compareTo(b.id));
      var score = 0;
      for (final value in values) {
        score += switch (value.feedback) {
          ResponsivenessFeedback.worked => 2,
          ResponsivenessFeedback.moreLikeThis => 2,
          ResponsivenessFeedback.neutral => 0,
          ResponsivenessFeedback.unsure => 0,
          ResponsivenessFeedback.neverSuggest => -4,
        };
      }
      if (score <= 0) continue;
      final first = values.first;
      result.add(
        ResponsivenessCandidate(
          ownerId: ownerId,
          signalKind: first.signalKind,
          action: first.action,
          score: score,
          evidenceIds: List.unmodifiable(values.map((e) => e.id)),
        ),
      );
    }
    return List.unmodifiable(result);
  }
}

class SupportCard {
  const SupportCard({
    required this.id,
    required this.ownerId,
    required this.recipientId,
    required this.signalId,
    required this.signalKind,
    required this.action,
    required this.preferenceOrigin,
    required this.createdAt,
    required this.expiresAt,
    this.customActionKey,
  });

  final String id;
  final String ownerId;
  final String recipientId;
  final String signalId;
  final RelationshipSignalKind signalKind;
  final SupportActionKind action;
  final String? customActionKey;
  final SupportPreferenceOrigin preferenceOrigin;
  final DateTime createdAt;
  final DateTime? expiresAt;
}

class SupportEngine {
  const SupportEngine();

  List<SupportCard> buildCards({
    required String ownerId,
    required String recipientId,
    required DateTime at,
    required Iterable<RelationshipSignal> signals,
    required Iterable<SupportPreference> preferences,
    Iterable<ResponsivenessCandidate> learnedCandidates = const [],
  }) {
    final activeSignals = const RelationshipSignalEngine().selectActive(
      ownerId: ownerId,
      recipientId: recipientId,
      at: at,
      signals: signals,
    );
    final cards = <SupportCard>[];
    for (final signal in activeSignals) {
      final chosen = _choosePreference(
        ownerId: ownerId,
        signal: signal,
        at: at,
        preferences: preferences,
        learnedCandidates: learnedCandidates,
      );
      if (chosen == null) continue;
      cards.add(
        SupportCard(
          id: 'support-${signal.id}-${chosen.logicalAction}',
          ownerId: ownerId,
          recipientId: recipientId,
          signalId: signal.id,
          signalKind: signal.kind,
          action: chosen.action,
          customActionKey: chosen.customActionKey,
          preferenceOrigin: chosen.origin,
          createdAt: at,
          expiresAt: signal.expiresAt,
        ),
      );
    }
    cards.sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(cards);
  }

  SupportPreference? _choosePreference({
    required String ownerId,
    required RelationshipSignal signal,
    required DateTime at,
    required Iterable<SupportPreference> preferences,
    required Iterable<ResponsivenessCandidate> learnedCandidates,
  }) {
    final eligible = preferences
        .where((p) =>
            p.ownerId == ownerId &&
            p.isActiveAt(at) &&
            (p.signalKind == null || p.signalKind == signal.kind))
        .toList();

    for (final candidate in learnedCandidates) {
      if (candidate.ownerId != ownerId ||
          (candidate.signalKind != null &&
              candidate.signalKind != signal.kind)) {
        continue;
      }
      eligible.add(
        SupportPreference(
          id: 'learned-${candidate.action.name}',
          ownerId: ownerId,
          signalKind: candidate.signalKind,
          action: candidate.action,
          origin: SupportPreferenceOrigin.observedCandidate,
          createdAt: at,
          priority: candidate.score,
        ),
      );
    }

    if (eligible.isEmpty) {
      return _genericFor(ownerId: ownerId, signal: signal, at: at);
    }
    eligible.sort((a, b) {
      final origin = _originRank(b.origin).compareTo(_originRank(a.origin));
      if (origin != 0) return origin;
      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) return priority;
      final created = b.createdAt.compareTo(a.createdAt);
      if (created != 0) return created;
      return a.id.compareTo(b.id);
    });
    return eligible.first;
  }

  SupportPreference _genericFor({
    required String ownerId,
    required RelationshipSignal signal,
    required DateTime at,
  }) {
    final action = switch (signal.kind) {
      RelationshipSignalKind.space => SupportActionKind.giveSpace,
      RelationshipSignalKind.listen => SupportActionKind.listen,
      RelationshipSignalKind.practicalHelp => SupportActionKind.practicalHelp,
      RelationshipSignalKind.presence => SupportActionKind.quietPresence,
      RelationshipSignalKind.touch => SupportActionKind.affection,
      RelationshipSignalKind.fun => SupportActionKind.distraction,
      RelationshipSignalKind.love => SupportActionKind.affection,
      RelationshipSignalKind.talk => SupportActionKind.checkIn,
      RelationshipSignalKind.flirt => SupportActionKind.companionship,
      RelationshipSignalKind.intimacy => SupportActionKind.companionship,
      RelationshipSignalKind.surprise => SupportActionKind.encouragement,
      RelationshipSignalKind.custom => SupportActionKind.checkIn,
    };
    return SupportPreference(
      id: 'generic-${signal.kind.name}-${action.name}',
      ownerId: ownerId,
      signalKind: signal.kind,
      action: action,
      origin: SupportPreferenceOrigin.generic,
      createdAt: at,
    );
  }
}

int _originRank(SupportPreferenceOrigin origin) => switch (origin) {
      SupportPreferenceOrigin.explicitCurrent => 5,
      SupportPreferenceOrigin.explicitStanding => 4,
      SupportPreferenceOrigin.confirmedLearned => 3,
      SupportPreferenceOrigin.observedCandidate => 2,
      SupportPreferenceOrigin.generic => 1,
    };
