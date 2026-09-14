import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 16);

  RoomSignal signal(RoomSignalKind kind,
          {String id = 's',
          int priority = 0,
          DateTime? createdAt,
          DateTime? expiresAt,
          DateTime? revokedAt}) =>
      RoomSignal(
        id: id,
        ownerId: 'a',
        partnerId: 'b',
        kind: kind,
        priority: priority,
        createdAt: createdAt ?? now.subtract(const Duration(minutes: 5)),
        expiresAt: expiresAt,
        revokedAt: revokedAt,
      );

  RelationshipCategoryGrant grant(RoomSignalKind kind) =>
      RelationshipCategoryGrant(
        id: 'g-${kind.name}',
        ownerId: 'a',
        recipientId: 'b',
        category: 'relationship.room.${kind.name}',
        capabilities: const {RelationshipCapability.relationshipIntelligence},
        visibility: RelationshipVisibility.engineOnly,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

  test('read the room maps explicit space to give-space', () {
    final result = const RelationshipSituationEngine().readTheRoom(
      ownerId: 'a',
      partnerId: 'b',
      at: now,
      signals: [signal(RoomSignalKind.needsSpace)],
      grants: [grant(RoomSignalKind.needsSpace)],
    );
    expect(result!.action, RoomActionKind.giveSpace);
  });

  test('permission and recipient scope fail closed', () {
    final engine = const RelationshipSituationEngine();
    expect(
        engine.readTheRoom(
            ownerId: 'a',
            partnerId: 'b',
            at: now,
            signals: [signal(RoomSignalKind.wantsFun)],
            grants: const []),
        isNull);
    expect(
        engine.readTheRoom(
            ownerId: 'a',
            partnerId: 'c',
            at: now,
            signals: [signal(RoomSignalKind.wantsFun)],
            grants: [grant(RoomSignalKind.wantsFun)]),
        isNull);
  });

  test('priority then recency choose deterministic room action', () {
    final result = const RelationshipSituationEngine().readTheRoom(
      ownerId: 'a',
      partnerId: 'b',
      at: now,
      signals: [
        signal(RoomSignalKind.wantsFun,
            id: 'old-high',
            priority: 5,
            createdAt: now.subtract(const Duration(minutes: 20))),
        signal(RoomSignalKind.wantsCheckIn,
            id: 'new-low',
            priority: 1,
            createdAt: now.subtract(const Duration(minutes: 1))),
      ],
      grants: [
        grant(RoomSignalKind.wantsFun),
        grant(RoomSignalKind.wantsCheckIn)
      ],
    );
    expect(result!.signalId, 'old-high');
    expect(result.action, RoomActionKind.bringFun);
  });

  test('relationship weather is categorical, not a score', () {
    final weather = const RelationshipSituationEngine().weather(
      ownerId: 'a',
      partnerId: 'b',
      at: now,
      signals: [signal(RoomSignalKind.wantsCloseness, id: 'close')],
      grants: [grant(RoomSignalKind.wantsCloseness)],
    );
    expect(weather.kind, RelationshipWeatherKind.connected);
    expect(weather.basedOnSignalIds, ['close']);
  });

  test('multiple permitted signals produce mixed weather without judgment', () {
    final weather = const RelationshipSituationEngine().weather(
      ownerId: 'a',
      partnerId: 'b',
      at: now,
      signals: [
        signal(RoomSignalKind.needsSpace, id: 'space'),
        signal(RoomSignalKind.readyToTalk, id: 'talk')
      ],
      grants: [
        grant(RoomSignalKind.needsSpace),
        grant(RoomSignalKind.readyToTalk)
      ],
    );
    expect(weather.kind, RelationshipWeatherKind.mixed);
  });

  test('zero-log micro moment suppresses low-value prompt', () {
    final decision = const RelationshipSituationEngine().chooseMicroMoment(
      userInteractedRecently: false,
      candidates: [
        MicroMomentCandidate(
            id: 'x',
            action: RoomActionKind.checkIn,
            informationValue: 0.4,
            userBurden: 0.4)
      ],
    );
    expect(decision.shouldSurface, isFalse);
    expect(decision.reason, 'low_information_value');
  });

  test('zero-log avoids prompting after recent interaction', () {
    final decision = const RelationshipSituationEngine().chooseMicroMoment(
      userInteractedRecently: true,
      candidates: [
        MicroMomentCandidate(
            id: 'x',
            action: RoomActionKind.checkIn,
            informationValue: 1,
            userBurden: 0)
      ],
    );
    expect(decision.shouldSurface, isFalse);
    expect(decision.reason, 'recent_interaction');
  });

  test('highest-value low-burden micro moment wins deterministically', () {
    final decision = const RelationshipSituationEngine().chooseMicroMoment(
      userInteractedRecently: false,
      candidates: [
        MicroMomentCandidate(
            id: 'b',
            action: RoomActionKind.checkIn,
            informationValue: 0.9,
            userBurden: 0.2),
        MicroMomentCandidate(
            id: 'a',
            action: RoomActionKind.beClose,
            informationValue: 0.9,
            userBurden: 0.2),
      ],
    );
    expect(decision.shouldSurface, isTrue);
    expect(decision.candidate!.id, 'a');
  });

  test('expired and revoked room signals are ignored', () {
    final weather = const RelationshipSituationEngine().weather(
      ownerId: 'a',
      partnerId: 'b',
      at: now,
      signals: [
        signal(RoomSignalKind.wantsFun,
            id: 'expired',
            createdAt: now.subtract(const Duration(hours: 2)),
            expiresAt: now),
        signal(RoomSignalKind.wantsCloseness, id: 'revoked', revokedAt: now),
      ],
      grants: [
        grant(RoomSignalKind.wantsFun),
        grant(RoomSignalKind.wantsCloseness)
      ],
    );
    expect(weather.kind, RelationshipWeatherKind.unknown);
  });
}
