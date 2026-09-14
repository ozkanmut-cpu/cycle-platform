import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 15);

  CoupleMemoryItem item({
    required String id,
    required CoupleMemoryKind kind,
    required String key,
    required String value,
    RelationshipVisibility visibility = RelationshipVisibility.fullyShared,
    int version = 1,
    DateTime? createdAt,
    DateTime? validUntil,
    DateTime? revokedAt,
  }) =>
      CoupleMemoryItem(
        id: id,
        ownerId: 'a',
        partnerId: 'b',
        kind: kind,
        key: key,
        value: value,
        createdAt: createdAt ?? now.subtract(const Duration(minutes: 10)),
        visibility: visibility,
        version: version,
        validUntil: validUntil,
        revokedAt: revokedAt,
      );

  RelationshipCategoryGrant grant({
    required CoupleMemoryKind kind,
    required String key,
    required RelationshipCapability capability,
    RelationshipVisibility visibility = RelationshipVisibility.fullyShared,
  }) =>
      RelationshipCategoryGrant(
        id: 'g-${kind.name}-$key-${capability.name}',
        ownerId: 'a',
        recipientId: 'b',
        category: 'relationship.memory.${kind.name}.$key',
        capabilities: {capability},
        visibility: visibility,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

  test('partner manual exposes only explicitly granted raw memory', () {
    final manual = const CoupleMemoryEngine().buildPartnerManual(
      ownerId: 'a',
      partnerId: 'b',
      capability: RelationshipCapability.view,
      at: now,
      items: [
        item(
          id: 'nick',
          kind: CoupleMemoryKind.nickname,
          key: 'preferred',
          value: 'Sunshine',
        ),
      ],
      grants: [
        grant(
          kind: CoupleMemoryKind.nickname,
          key: 'preferred',
          capability: RelationshipCapability.view,
        ),
      ],
    );
    expect(manual.entries.single.value, 'Sunshine');
  });

  test('engine-only manual entry never exposes raw value', () {
    final manual = const CoupleMemoryEngine().buildPartnerManual(
      ownerId: 'a',
      partnerId: 'b',
      capability: RelationshipCapability.relationshipIntelligence,
      at: now,
      items: [
        item(
          id: 'support',
          kind: CoupleMemoryKind.supportPreference,
          key: 'stress',
          value: 'listen first',
          visibility: RelationshipVisibility.engineOnly,
        ),
      ],
      grants: [
        grant(
          kind: CoupleMemoryKind.supportPreference,
          key: 'stress',
          capability: RelationshipCapability.relationshipIntelligence,
          visibility: RelationshipVisibility.engineOnly,
        ),
      ],
    );
    expect(manual.entries.single.value, isNull);
    expect(manual.entries.single.exposesRawValue, isFalse);
  });

  test('view grant does not imply playful or intimacy use', () {
    final memory = item(
      id: 'boundary',
      kind: CoupleMemoryKind.boundary,
      key: 'teasing',
      value: 'avoid public teasing',
    );
    final viewGrant = grant(
      kind: CoupleMemoryKind.boundary,
      key: 'teasing',
      capability: RelationshipCapability.view,
    );
    final playful = const CoupleMemoryEngine().buildPartnerManual(
      ownerId: 'a',
      partnerId: 'b',
      capability: RelationshipCapability.playful,
      at: now,
      items: [memory],
      grants: [viewGrant],
    );
    final intimacy = const CoupleMemoryEngine().buildPartnerManual(
      ownerId: 'a',
      partnerId: 'b',
      capability: RelationshipCapability.intimacy,
      at: now,
      items: [memory],
      grants: [viewGrant],
    );
    expect(playful.entries, isEmpty);
    expect(intimacy.entries, isEmpty);
  });

  test('latest version wins for the same logical memory key', () {
    final manual = const CoupleMemoryEngine().buildPartnerManual(
      ownerId: 'a',
      partnerId: 'b',
      capability: RelationshipCapability.view,
      at: now,
      items: [
        item(
          id: 'old',
          kind: CoupleMemoryKind.partnerManual,
          key: 'comfort',
          value: 'give advice',
          version: 1,
        ),
        item(
          id: 'new',
          kind: CoupleMemoryKind.partnerManual,
          key: 'comfort',
          value: 'listen first',
          version: 2,
        ),
      ],
      grants: [
        grant(
          kind: CoupleMemoryKind.partnerManual,
          key: 'comfort',
          capability: RelationshipCapability.view,
        ),
      ],
    );
    expect(manual.entries.single.id, 'new');
    expect(manual.entries.single.value, 'listen first');
  });

  test('expired revoked and wrong-partner memory never projects', () {
    final expired = item(
      id: 'expired',
      kind: CoupleMemoryKind.importantDate,
      key: 'trip',
      value: 'September',
      createdAt: now.subtract(const Duration(days: 2)),
      validUntil: now,
    );
    final revoked = item(
      id: 'revoked',
      kind: CoupleMemoryKind.favorite,
      key: 'food',
      value: 'sushi',
      revokedAt: now,
    );
    final wrongPartner = CoupleMemoryItem(
      id: 'wrong',
      ownerId: 'a',
      partnerId: 'c',
      kind: CoupleMemoryKind.sharedMemory,
      key: 'holiday',
      value: 'beach',
      createdAt: now.subtract(const Duration(hours: 1)),
      visibility: RelationshipVisibility.fullyShared,
    );
    final manual = const CoupleMemoryEngine().buildPartnerManual(
      ownerId: 'a',
      partnerId: 'b',
      capability: RelationshipCapability.view,
      at: now,
      items: [expired, revoked, wrongPartner],
      grants: const [],
    );
    expect(manual.entries, isEmpty);
  });

  test('ordering is deterministic by kind key and id', () {
    final entries = [
      item(
        id: 'b',
        kind: CoupleMemoryKind.favorite,
        key: 'music',
        value: 'jazz',
      ),
      item(
        id: 'a',
        kind: CoupleMemoryKind.nickname,
        key: 'preferred',
        value: 'Love',
      ),
    ];
    final grants = [
      grant(
        kind: CoupleMemoryKind.favorite,
        key: 'music',
        capability: RelationshipCapability.view,
      ),
      grant(
        kind: CoupleMemoryKind.nickname,
        key: 'preferred',
        capability: RelationshipCapability.view,
      ),
    ];
    final first = const CoupleMemoryEngine().buildPartnerManual(
      ownerId: 'a',
      partnerId: 'b',
      capability: RelationshipCapability.view,
      at: now,
      items: entries,
      grants: grants,
    );
    final second = const CoupleMemoryEngine().buildPartnerManual(
      ownerId: 'a',
      partnerId: 'b',
      capability: RelationshipCapability.view,
      at: now,
      items: entries.reversed,
      grants: grants.reversed,
    );
    expect(first.entries.map((e) => e.id), second.entries.map((e) => e.id));
  });
}
