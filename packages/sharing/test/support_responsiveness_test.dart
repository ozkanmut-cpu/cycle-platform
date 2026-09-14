import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 10, 30);

  RelationshipSignal signal(RelationshipSignalKind kind) => RelationshipSignal(
        id: 'signal-${kind.name}',
        ownerId: 'a',
        recipientId: 'b',
        kind: kind,
        origin: RelationshipSignalOrigin.explicit,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

  test('current explicit preference outranks learned and generic support', () {
    const responsiveness = ResponsivenessEngine();
    final learned = responsiveness.deriveCandidates(
      ownerId: 'a',
      observations: [
        ResponsivenessObservation(
          id: 'obs-1',
          ownerId: 'a',
          signalKind: RelationshipSignalKind.space,
          action: SupportActionKind.checkIn,
          feedback: ResponsivenessFeedback.worked,
          observedAt: now,
        ),
      ],
    );

    final cards = const SupportEngine().buildCards(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      signals: [signal(RelationshipSignalKind.space)],
      preferences: [
        SupportPreference(
          id: 'explicit',
          ownerId: 'a',
          signalKind: RelationshipSignalKind.space,
          action: SupportActionKind.giveSpace,
          origin: SupportPreferenceOrigin.explicitCurrent,
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
      ],
      learnedCandidates: learned,
    );

    expect(cards.single.action, SupportActionKind.giveSpace);
    expect(cards.single.preferenceOrigin, SupportPreferenceOrigin.explicitCurrent);
  });

  test('confirmed learned preference outranks observed candidate', () {
    final cards = const SupportEngine().buildCards(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      signals: [signal(RelationshipSignalKind.practicalHelp)],
      preferences: [
        SupportPreference(
          id: 'confirmed',
          ownerId: 'a',
          signalKind: RelationshipSignalKind.practicalHelp,
          action: SupportActionKind.practicalHelp,
          origin: SupportPreferenceOrigin.confirmedLearned,
          createdAt: now,
        ),
      ],
      learnedCandidates: const [
        ResponsivenessCandidate(
          ownerId: 'a',
          signalKind: RelationshipSignalKind.practicalHelp,
          action: SupportActionKind.checkIn,
          score: 10,
          evidenceIds: ['obs'],
        ),
      ],
    );

    expect(cards.single.action, SupportActionKind.practicalHelp);
    expect(cards.single.preferenceOrigin, SupportPreferenceOrigin.confirmedLearned);
  });

  test('never-suggest feedback prevents positive learned candidate', () {
    final candidates = const ResponsivenessEngine().deriveCandidates(
      ownerId: 'a',
      observations: [
        ResponsivenessObservation(
          id: 'worked',
          ownerId: 'a',
          action: SupportActionKind.affection,
          feedback: ResponsivenessFeedback.worked,
          observedAt: now,
        ),
        ResponsivenessObservation(
          id: 'never',
          ownerId: 'a',
          action: SupportActionKind.affection,
          feedback: ResponsivenessFeedback.neverSuggest,
          observedAt: now,
        ),
      ],
    );
    expect(candidates, isEmpty);
  });

  test('space falls back to do-nothing style giveSpace action', () {
    final cards = const SupportEngine().buildCards(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      signals: [signal(RelationshipSignalKind.space)],
      preferences: const [],
    );
    expect(cards.single.action, SupportActionKind.giveSpace);
    expect(cards.single.preferenceOrigin, SupportPreferenceOrigin.generic);
  });

  test('expired preference is ignored', () {
    final cards = const SupportEngine().buildCards(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      signals: [signal(RelationshipSignalKind.listen)],
      preferences: [
        SupportPreference(
          id: 'expired',
          ownerId: 'a',
          signalKind: RelationshipSignalKind.listen,
          action: SupportActionKind.practicalHelp,
          origin: SupportPreferenceOrigin.explicitCurrent,
          createdAt: now.subtract(const Duration(hours: 2)),
          expiresAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
    );
    expect(cards.single.action, SupportActionKind.listen);
  });

  test('support card ids and ordering are deterministic', () {
    final cards = const SupportEngine().buildCards(
      ownerId: 'a',
      recipientId: 'b',
      at: now,
      signals: [
        signal(RelationshipSignalKind.talk),
        signal(RelationshipSignalKind.space),
      ],
      preferences: const [],
    );
    final ids = cards.map((e) => e.id).toList();
    expect(ids, [...ids]..sort());
  });
}
