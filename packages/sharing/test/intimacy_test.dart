import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 11, 30);

  IntimacyPreference pref(String owner, String partner,
          {IntimacyPreferenceLevel level =
              IntimacyPreferenceLevel.interested}) =>
      IntimacyPreference(
        id: 'p-$owner',
        ownerId: owner,
        partnerId: partner,
        category: 'touch',
        optionKey: 'massage',
        level: level,
        createdAt: now.subtract(const Duration(days: 1)),
      );

  IntimacyWillingness willing(
          String owner, String partner, CurrentWillingness value,
          {DateTime? expiresAt, DateTime? cooldownUntil}) =>
      IntimacyWillingness(
        id: 'w-$owner-${value.name}',
        ownerId: owner,
        partnerId: partner,
        category: 'touch',
        optionKey: 'massage',
        willingness: value,
        createdAt: now.subtract(const Duration(minutes: 5)),
        expiresAt: expiresAt ?? now.add(const Duration(minutes: 30)),
        cooldownUntil: cooldownUntil,
      );

  RelationshipCategoryGrant grant(String owner, String recipient) =>
      RelationshipCategoryGrant(
        id: 'g-$owner-$recipient',
        ownerId: owner,
        recipientId: recipient,
        category: 'relationship.intimacy.touch',
        capabilities: const {RelationshipCapability.intimacy},
        visibility: RelationshipVisibility.engineOnly,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

  List<IntimacyDecision> evaluate({
    required List<IntimacyWillingness> willingness,
    List<IntimacyPreference>? preferences,
    List<IntimacyBoundary> boundaries = const [],
    List<RelationshipCategoryGrant>? grants,
  }) =>
      const IntimacyEngine().evaluate(
        participantAId: 'a',
        participantBId: 'b',
        at: now,
        preferences: preferences ?? [pref('a', 'b'), pref('b', 'a')],
        willingness: willingness,
        boundaries: boundaries,
        grants: grants ?? [grant('a', 'b'), grant('b', 'a')],
      );

  test('long-term preference alone never becomes current consent', () {
    final decisions = evaluate(willingness: const []);
    expect(decisions, isEmpty);
  });

  test('no response is not consent', () {
    final decisions = evaluate(
      willingness: [willing('a', 'b', CurrentWillingness.yes)],
    );
    expect(decisions, isEmpty);
  });

  test('two current yes values create time-limited mutual willingness', () {
    final decisions = evaluate(
      willingness: [
        willing('a', 'b', CurrentWillingness.yes),
        willing('b', 'a', CurrentWillingness.yes),
      ],
    );
    expect(decisions, hasLength(1));
    expect(decisions.single.kind, IntimacyDecisionKind.mutuallyWilling);
    expect(decisions.single.expiresAt, now.add(const Duration(minutes: 30)));
  });

  test('no and notTonight suppress matching', () {
    for (final value in [
      CurrentWillingness.no,
      CurrentWillingness.notTonight
    ]) {
      final decisions = evaluate(
        willingness: [
          willing('a', 'b', value),
          willing('b', 'a', CurrentWillingness.yes),
        ],
      );
      expect(decisions, isEmpty);
    }
  });

  test('ask-first or maybe yields ask-first, never consent', () {
    for (final value in [
      CurrentWillingness.askFirst,
      CurrentWillingness.maybe,
    ]) {
      final decisions = evaluate(
        willingness: [
          willing('a', 'b', value),
          willing('b', 'a', CurrentWillingness.yes),
        ],
      );
      expect(decisions.single.kind, IntimacyDecisionKind.askFirst);
    }
  });

  test('hard boundary blocks even when both currently say yes', () {
    final decisions = evaluate(
      willingness: [
        willing('a', 'b', CurrentWillingness.yes),
        willing('b', 'a', CurrentWillingness.yes),
      ],
      boundaries: [
        IntimacyBoundary(
          id: 'boundary-a',
          ownerId: 'a',
          partnerId: 'b',
          category: 'touch',
          optionKey: 'massage',
          blocked: true,
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
    );
    expect(decisions, isEmpty);
  });

  test('ask-first boundary downgrades two yes values to ask-first', () {
    final decisions = evaluate(
      willingness: [
        willing('a', 'b', CurrentWillingness.yes),
        willing('b', 'a', CurrentWillingness.yes),
      ],
      boundaries: [
        IntimacyBoundary(
          id: 'ask-a',
          ownerId: 'a',
          partnerId: 'b',
          category: 'touch',
          askFirst: true,
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
    );
    expect(decisions.single.kind, IntimacyDecisionKind.askFirst);
  });

  test('cooldown suppresses repeated intimacy suggestions', () {
    final decisions = evaluate(
      willingness: [
        willing(
          'a',
          'b',
          CurrentWillingness.yes,
          cooldownUntil: now.add(const Duration(hours: 12)),
        ),
        willing('b', 'a', CurrentWillingness.yes),
      ],
    );
    expect(decisions, isEmpty);
  });

  test('both directions require explicit intimacy-purpose permission', () {
    final decisions = evaluate(
      willingness: [
        willing('a', 'b', CurrentWillingness.yes),
        willing('b', 'a', CurrentWillingness.yes),
      ],
      grants: [grant('a', 'b')],
    );
    expect(decisions, isEmpty);
  });

  test('notInterested long-term preference prevents intimacy match', () {
    final decisions = evaluate(
      preferences: [
        pref('a', 'b', level: IntimacyPreferenceLevel.notInterested),
        pref('b', 'a'),
      ],
      willingness: [
        willing('a', 'b', CurrentWillingness.yes),
        willing('b', 'a', CurrentWillingness.yes),
      ],
    );
    expect(decisions, isEmpty);
  });
}
