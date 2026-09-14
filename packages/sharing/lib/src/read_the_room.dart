import 'relationship_policy.dart';

enum RoomSignalKind {
  needsSpace,
  wantsCheckIn,
  wantsCloseness,
  needsPracticalHelp,
  wantsFun,
  readyToTalk,
  neutral
}

enum RoomActionKind {
  giveSpace,
  checkIn,
  beClose,
  helpPractically,
  bringFun,
  inviteConversation,
  none
}

enum RelationshipWeatherKind {
  quiet,
  open,
  connected,
  playful,
  supportive,
  mixed,
  unknown
}

class RoomSignal {
  RoomSignal({
    required this.id,
    required this.ownerId,
    required this.partnerId,
    required this.kind,
    required this.createdAt,
    this.expiresAt,
    this.revokedAt,
    this.priority = 0,
  }) {
    if (id.trim().isEmpty ||
        ownerId.trim().isEmpty ||
        partnerId.trim().isEmpty) {
      throw const RelationshipPolicyException(
          'room signal scope must not be blank');
    }
    if (ownerId == partnerId) {
      throw const RelationshipPolicyException(
          'room signal owner and partner must differ');
    }
  }

  final String id;
  final String ownerId;
  final String partnerId;
  final RoomSignalKind kind;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final int priority;

  bool isActiveAt(DateTime at) {
    if (at.isBefore(createdAt) || revokedAt != null) return false;
    return expiresAt == null || at.isBefore(expiresAt!);
  }
}

class ReadTheRoomDecision {
  const ReadTheRoomDecision(
      {required this.signalId, required this.action, required this.kind});
  final String signalId;
  final RoomActionKind action;
  final RoomSignalKind kind;
}

class RelationshipWeather {
  const RelationshipWeather(
      {required this.kind, required this.basedOnSignalIds});
  final RelationshipWeatherKind kind;
  final List<String> basedOnSignalIds;
}

class MicroMomentCandidate {
  const MicroMomentCandidate({
    required this.id,
    required this.action,
    required this.informationValue,
    required this.userBurden,
    this.priority = 0,
  });
  final String id;
  final RoomActionKind action;
  final double informationValue;
  final double userBurden;
  final int priority;
}

class MicroMomentDecision {
  const MicroMomentDecision(
      {required this.shouldSurface, required this.reason, this.candidate});
  final bool shouldSurface;
  final String reason;
  final MicroMomentCandidate? candidate;
}

class RelationshipSituationEngine {
  const RelationshipSituationEngine(
      {this.firewall = const RelationshipPermissionFirewall()});
  final RelationshipPermissionFirewall firewall;

  ReadTheRoomDecision? readTheRoom({
    required String ownerId,
    required String partnerId,
    required DateTime at,
    required Iterable<RoomSignal> signals,
    required Iterable<RelationshipCategoryGrant> grants,
  }) {
    final active = _active(ownerId, partnerId, at, signals);
    for (final signal in active) {
      final allowed = firewall
          .evaluate(
            request: RelationshipAccessRequest(
              ownerId: ownerId,
              recipientId: partnerId,
              category: 'relationship.room.${signal.kind.name}',
              capability: RelationshipCapability.relationshipIntelligence,
              at: at,
            ),
            grants: grants,
          )
          .allowed;
      if (!allowed) continue;
      return ReadTheRoomDecision(
        signalId: signal.id,
        kind: signal.kind,
        action: _actionFor(signal.kind),
      );
    }
    return null;
  }

  RelationshipWeather weather({
    required String ownerId,
    required String partnerId,
    required DateTime at,
    required Iterable<RoomSignal> signals,
    required Iterable<RelationshipCategoryGrant> grants,
  }) {
    final permitted = <RoomSignal>[];
    for (final signal in _active(ownerId, partnerId, at, signals)) {
      final allowed = firewall
          .evaluate(
            request: RelationshipAccessRequest(
              ownerId: ownerId,
              recipientId: partnerId,
              category: 'relationship.room.${signal.kind.name}',
              capability: RelationshipCapability.relationshipIntelligence,
              at: at,
            ),
            grants: grants,
          )
          .allowed;
      if (allowed) permitted.add(signal);
    }
    if (permitted.isEmpty) {
      return const RelationshipWeather(
          kind: RelationshipWeatherKind.unknown, basedOnSignalIds: []);
    }
    final kinds = permitted.map((e) => e.kind).toSet();
    final kind = _weatherFor(kinds);
    final ids = permitted.map((e) => e.id).toList()..sort();
    return RelationshipWeather(
        kind: kind, basedOnSignalIds: List.unmodifiable(ids));
  }

  MicroMomentDecision chooseMicroMoment({
    required bool userInteractedRecently,
    required Iterable<MicroMomentCandidate> candidates,
    double threshold = 0.55,
  }) {
    if (userInteractedRecently) {
      return const MicroMomentDecision(
          shouldSurface: false, reason: 'recent_interaction');
    }
    final eligible = candidates.where((c) {
      final value = c.informationValue.clamp(0.0, 1.0).toDouble();
      final burden = c.userBurden.clamp(0.0, 1.0).toDouble();
      return value - (burden * 0.5) >= threshold;
    }).toList()
      ..sort((a, b) {
        final priority = b.priority.compareTo(a.priority);
        if (priority != 0) return priority;
        final av = a.informationValue - (a.userBurden * 0.5);
        final bv = b.informationValue - (b.userBurden * 0.5);
        final value = bv.compareTo(av);
        if (value != 0) return value;
        return a.id.compareTo(b.id);
      });
    if (eligible.isEmpty) {
      return const MicroMomentDecision(
          shouldSurface: false, reason: 'low_information_value');
    }
    return MicroMomentDecision(
      shouldSurface: true,
      reason: 'meaningful_low_burden_moment',
      candidate: eligible.first,
    );
  }

  List<RoomSignal> _active(String ownerId, String partnerId, DateTime at,
      Iterable<RoomSignal> signals) {
    final values = signals
        .where((s) =>
            s.ownerId == ownerId &&
            s.partnerId == partnerId &&
            s.isActiveAt(at))
        .toList()
      ..sort((a, b) {
        final priority = b.priority.compareTo(a.priority);
        if (priority != 0) return priority;
        final created = b.createdAt.compareTo(a.createdAt);
        if (created != 0) return created;
        return a.id.compareTo(b.id);
      });
    return values;
  }
}

RoomActionKind _actionFor(RoomSignalKind kind) => switch (kind) {
      RoomSignalKind.needsSpace => RoomActionKind.giveSpace,
      RoomSignalKind.wantsCheckIn => RoomActionKind.checkIn,
      RoomSignalKind.wantsCloseness => RoomActionKind.beClose,
      RoomSignalKind.needsPracticalHelp => RoomActionKind.helpPractically,
      RoomSignalKind.wantsFun => RoomActionKind.bringFun,
      RoomSignalKind.readyToTalk => RoomActionKind.inviteConversation,
      RoomSignalKind.neutral => RoomActionKind.none,
    };

RelationshipWeatherKind _weatherFor(Set<RoomSignalKind> kinds) {
  if (kinds.length > 1) return RelationshipWeatherKind.mixed;
  final kind = kinds.single;
  return switch (kind) {
    RoomSignalKind.needsSpace => RelationshipWeatherKind.quiet,
    RoomSignalKind.readyToTalk ||
    RoomSignalKind.wantsCheckIn =>
      RelationshipWeatherKind.open,
    RoomSignalKind.wantsCloseness => RelationshipWeatherKind.connected,
    RoomSignalKind.wantsFun => RelationshipWeatherKind.playful,
    RoomSignalKind.needsPracticalHelp => RelationshipWeatherKind.supportive,
    RoomSignalKind.neutral => RelationshipWeatherKind.unknown,
  };
}
