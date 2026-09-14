import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 11);

  RelationshipCategoryGrant grant(
          String owner, String recipient, String category) =>
      RelationshipCategoryGrant(
        id: 'g-$owner-$recipient-$category',
        ownerId: owner,
        recipientId: recipient,
        category: 'relationship.mutuality.$category',
        capabilities: const {RelationshipCapability.relationshipIntelligence},
        visibility: RelationshipVisibility.engineOnly,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

  MutualSelection selection({
    required String id,
    required String owner,
    required String partner,
    required String category,
    required Set<String> options,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? revokedAt,
    int version = 1,
  }) =>
      MutualSelection(
        id: id,
        ownerId: owner,
        partnerId: partner,
        category: category,
        optionKeys: options,
        createdAt: createdAt ?? now.subtract(const Duration(minutes: 5)),
        expiresAt: expiresAt,
        revokedAt: revokedAt,
        version: version,
      );

  test('reveals only the private intersection', () {
    final matches = const MutualityEngine().findMatches(
      participantAId: 'a',
      participantBId: 'b',
      at: now,
      selections: [
        selection(
          id: 'a1',
          owner: 'a',
          partner: 'b',
          category: 'evening',
          options: {'film', 'flirt', 'sex'},
        ),
        selection(
          id: 'b1',
          owner: 'b',
          partner: 'a',
          category: 'evening',
          options: {'film', 'flirt', 'walk'},
        ),
      ],
      grants: [grant('a', 'b', 'evening'), grant('b', 'a', 'evening')],
    );

    expect(matches.map((e) => e.optionKey).toList(), ['film', 'flirt']);
    expect(matches.any((e) => e.optionKey == 'sex'), isFalse);
    expect(matches.any((e) => e.optionKey == 'walk'), isFalse);
  });

  test('no mutual option returns no disclosure at all', () {
    final matches = const MutualityEngine().findMatches(
      participantAId: 'a',
      participantBId: 'b',
      at: now,
      selections: [
        selection(
          id: 'a1',
          owner: 'a',
          partner: 'b',
          category: 'date',
          options: {'home'},
        ),
        selection(
          id: 'b1',
          owner: 'b',
          partner: 'a',
          category: 'date',
          options: {'outside'},
        ),
      ],
      grants: [grant('a', 'b', 'date'), grant('b', 'a', 'date')],
    );
    expect(matches, isEmpty);
  });

  test('both directions require relationship-intelligence permission', () {
    final matches = const MutualityEngine().findMatches(
      participantAId: 'a',
      participantBId: 'b',
      at: now,
      selections: [
        selection(
          id: 'a1',
          owner: 'a',
          partner: 'b',
          category: 'film',
          options: {'comedy'},
        ),
        selection(
          id: 'b1',
          owner: 'b',
          partner: 'a',
          category: 'film',
          options: {'comedy'},
        ),
      ],
      grants: [grant('a', 'b', 'film')],
    );
    expect(matches, isEmpty);
  });

  test('expired or revoked selection cannot produce a match', () {
    final grants = [grant('a', 'b', 'talk'), grant('b', 'a', 'talk')];
    final expired = const MutualityEngine().findMatches(
      participantAId: 'a',
      participantBId: 'b',
      at: now,
      selections: [
        selection(
          id: 'a1',
          owner: 'a',
          partner: 'b',
          category: 'talk',
          options: {'now'},
          createdAt: now.subtract(const Duration(hours: 2)),
          expiresAt: now,
        ),
        selection(
          id: 'b1',
          owner: 'b',
          partner: 'a',
          category: 'talk',
          options: {'now'},
        ),
      ],
      grants: grants,
    );
    expect(expired, isEmpty);

    final revoked = const MutualityEngine().findMatches(
      participantAId: 'a',
      participantBId: 'b',
      at: now,
      selections: [
        selection(
          id: 'a2',
          owner: 'a',
          partner: 'b',
          category: 'talk',
          options: {'now'},
          revokedAt: now,
        ),
        selection(
          id: 'b2',
          owner: 'b',
          partner: 'a',
          category: 'talk',
          options: {'now'},
        ),
      ],
      grants: grants,
    );
    expect(revoked, isEmpty);
  });

  test('latest version supersedes older private selection deterministically',
      () {
    final matches = const MutualityEngine().findMatches(
      participantAId: 'a',
      participantBId: 'b',
      at: now,
      selections: [
        selection(
          id: 'a-old',
          owner: 'a',
          partner: 'b',
          category: 'activity',
          options: {'walk'},
          version: 1,
        ),
        selection(
          id: 'a-new',
          owner: 'a',
          partner: 'b',
          category: 'activity',
          options: {'film'},
          version: 2,
        ),
        selection(
          id: 'b1',
          owner: 'b',
          partner: 'a',
          category: 'activity',
          options: {'walk', 'film'},
        ),
      ],
      grants: [
        grant('a', 'b', 'activity'),
        grant('b', 'a', 'activity'),
      ],
    );
    expect(matches.map((e) => e.optionKey).toList(), ['film']);
  });

  test('match ids and participant ordering are stable', () {
    final selections = [
      selection(
        id: 'a1',
        owner: 'a',
        partner: 'b',
        category: 'food',
        options: {'pizza'},
      ),
      selection(
        id: 'b1',
        owner: 'b',
        partner: 'a',
        category: 'food',
        options: {'pizza'},
      ),
    ];
    final grants = [grant('a', 'b', 'food'), grant('b', 'a', 'food')];
    final first = const MutualityEngine().findMatches(
      participantAId: 'a',
      participantBId: 'b',
      at: now,
      selections: selections,
      grants: grants,
    );
    final second = const MutualityEngine().findMatches(
      participantAId: 'b',
      participantBId: 'a',
      at: now,
      selections: selections.reversed,
      grants: grants.reversed,
    );
    expect(first.single.id, second.single.id);
    expect(first.single.participantAId, 'a');
    expect(first.single.participantBId, 'b');
  });
}
