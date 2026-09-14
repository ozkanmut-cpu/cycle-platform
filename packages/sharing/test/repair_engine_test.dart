import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 14);
  RepairSignal signal(RepairState state,
          {DateTime? createdAt, DateTime? expiresAt, DateTime? revokedAt}) =>
      RepairSignal(
          id: 's-${state.name}-${createdAt?.millisecondsSinceEpoch ?? 0}',
          ownerId: 'a',
          partnerId: 'b',
          state: state,
          createdAt: createdAt ?? now.subtract(const Duration(minutes: 5)),
          expiresAt: expiresAt,
          revokedAt: revokedAt);
  RelationshipCategoryGrant grant(RepairState state) =>
      RelationshipCategoryGrant(
          id: 'g-${state.name}',
          ownerId: 'a',
          recipientId: 'b',
          category: 'relationship.repair.${state.name}',
          capabilities: const {RelationshipCapability.relationshipIntelligence},
          visibility: RelationshipVisibility.engineOnly,
          createdAt: now.subtract(const Duration(hours: 1)));

  test('need-space maps to give-space without blame', () {
    final r = const RepairEngine().suggest(
        ownerId: 'a',
        recipientId: 'b',
        at: now,
        signals: [signal(RepairState.needSpace)],
        grants: [grant(RepairState.needSpace)]);
    expect(r.single.action, RepairActionKind.giveSpace);
  });

  test('listen-dont-solve maps to listen-only', () {
    final r = const RepairEngine().suggest(
        ownerId: 'a',
        recipientId: 'b',
        at: now,
        signals: [signal(RepairState.listenDontSolve)],
        grants: [grant(RepairState.listenDontSolve)]);
    expect(r.single.action, RepairActionKind.listenOnly);
  });

  test('permission is required and wrong recipient does not leak', () {
    final engine = const RepairEngine();
    expect(
        engine.suggest(
            ownerId: 'a',
            recipientId: 'b',
            at: now,
            signals: [signal(RepairState.reconnect)],
            grants: const []),
        isEmpty);
    expect(
        engine.suggest(
            ownerId: 'a',
            recipientId: 'c',
            at: now,
            signals: [signal(RepairState.reconnect)],
            grants: [grant(RepairState.reconnect)]),
        isEmpty);
  });

  test('expired and revoked signals are ignored', () {
    final engine = const RepairEngine();
    expect(
        engine.suggest(ownerId: 'a', recipientId: 'b', at: now, signals: [
          signal(RepairState.readyToTalk,
              createdAt: now.subtract(const Duration(hours: 2)), expiresAt: now)
        ], grants: [
          grant(RepairState.readyToTalk)
        ]),
        isEmpty);
    expect(
        engine.suggest(
            ownerId: 'a',
            recipientId: 'b',
            at: now,
            signals: [signal(RepairState.apologize, revokedAt: now)],
            grants: [grant(RepairState.apologize)]),
        isEmpty);
  });

  test('latest active repair state wins deterministically', () {
    final old = signal(RepairState.needSpace,
        createdAt: now.subtract(const Duration(minutes: 10)));
    final fresh = signal(RepairState.readyToTalk,
        createdAt: now.subtract(const Duration(minutes: 1)));
    final r = const RepairEngine().suggest(
        ownerId: 'a',
        recipientId: 'b',
        at: now,
        signals: [old, fresh],
        grants: [grant(RepairState.needSpace), grant(RepairState.readyToTalk)]);
    expect(r.single.state, RepairState.readyToTalk);
    expect(r.single.action, RepairActionKind.inviteConversation);
  });
}
