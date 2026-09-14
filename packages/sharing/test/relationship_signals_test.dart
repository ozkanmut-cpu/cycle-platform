import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 10);

  RelationshipSignal signal({
    required String id,
    RelationshipSignalKind kind = RelationshipSignalKind.space,
    RelationshipSignalOrigin origin = RelationshipSignalOrigin.derived,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? revokedAt,
    String? customKey,
  }) =>
      RelationshipSignal(
        id: id,
        ownerId: 'a',
        recipientId: 'b',
        kind: kind,
        origin: origin,
        createdAt: createdAt ?? now.subtract(const Duration(minutes: 10)),
        expiresAt: expiresAt,
        revokedAt: revokedAt,
        customKey: customKey,
        partnerFacingText: 'safe text',
      );

  test('explicit signal supersedes derived signal in same logical domain', () {
    final selected = const RelationshipSignalEngine().selectActive(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      signals: [
        signal(id: 'derived', origin: RelationshipSignalOrigin.derived),
        signal(id: 'explicit', origin: RelationshipSignalOrigin.explicit),
      ],
    );
    expect(selected, hasLength(1));
    expect(selected.single.id, 'explicit');
  });

  test('expired and revoked signals are inactive', () {
    final selected = const RelationshipSignalEngine().selectActive(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      signals: [
        signal(id: 'expired', expiresAt: now),
        signal(id: 'revoked', revokedAt: now),
      ],
    );
    expect(selected, isEmpty);
  });

  test('different domains remain independent and deterministic', () {
    final selected = const RelationshipSignalEngine().selectActive(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      signals: [
        signal(id: 'talk', kind: RelationshipSignalKind.talk),
        signal(id: 'space', kind: RelationshipSignalKind.space),
      ],
    );
    expect(selected.map((e) => e.kind.name), ['space', 'talk']);
  });

  test('custom signal requires a stable custom key', () {
    expect(
      () => signal(id: 'custom', kind: RelationshipSignalKind.custom),
      throwsA(isA<RelationshipPolicyException>()),
    );
  });

  test('partner projection requires explicit view grant for signal category',
      () {
    final projection = const PartnerSignalProjector().project(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      signals: [signal(id: 'space')],
      grants: const [],
    );
    expect(projection, isEmpty);
  });

  test('partner projection succeeds only for correctly scoped grant', () {
    final grant = RelationshipCategoryGrant(
      id: 'g',
      ownerId: 'a',
      recipientId: 'b',
      category: 'relationship.signal.space',
      capabilities: const {RelationshipCapability.view},
      visibility: RelationshipVisibility.abstractShared,
      createdAt: now.subtract(const Duration(hours: 1)),
    );
    final projection = const PartnerSignalProjector().project(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      signals: [signal(id: 'space')],
      grants: [grant],
    );
    expect(projection, hasLength(1));
    expect(projection.single.visibility, RelationshipVisibility.abstractShared);
  });

  test('mixed recipient signal never leaks through projection', () {
    final mixed = RelationshipSignal(
      id: 'other',
      ownerId: 'a',
      recipientId: 'c',
      kind: RelationshipSignalKind.talk,
      origin: RelationshipSignalOrigin.explicit,
      createdAt: now,
    );
    final projection = const PartnerSignalProjector().project(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      signals: [mixed],
      grants: const [],
    );
    expect(projection, isEmpty);
  });
}
