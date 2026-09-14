import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 12);

  RelationshipCategoryGrant grant(
    RelationshipCapability capability,
    String category,
  ) =>
      RelationshipCategoryGrant(
        id: 'g-${capability.name}-$category',
        ownerId: 'a',
        recipientId: 'b',
        category: category,
        capabilities: {capability},
        visibility: RelationshipVisibility.engineOnly,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

  ClinicalTruthLayer truth(ClinicalTruthSeverity severity) =>
      ClinicalTruthLayer(
        id: 'truth',
        text: 'Seek urgent medical review now.',
        severity: severity,
        createdAt: now,
      );

  PlayfulComposition compose({
    PlayfulPresentationPreferences preferences =
        const PlayfulPresentationPreferences(),
    ClinicalTruthLayer? clinicalTruth,
    Iterable<RelationshipCategoryGrant>? grants,
    bool isSensitive = false,
    bool isSeriousClinical = false,
  }) =>
      const PlayfulEngine().compose(
        ownerId: 'a',
        recipientId: 'b',
        category: 'support',
        at: now,
        companionText: 'I am here with you 💛',
        preferences: preferences,
        clinicalTruth: clinicalTruth,
        isSensitive: isSensitive,
        isSeriousClinical: isSeriousClinical,
        grants: grants ??
            [
              grant(RelationshipCapability.playful,
                  'relationship.playful.support')
            ],
      );

  test('clinical truth is always first and unchanged', () {
    final result = compose(
      clinicalTruth: truth(ClinicalTruthSeverity.urgent),
      preferences: const PlayfulPresentationPreferences(allowInUrgent: true),
    );
    expect(result.layers.first.kind, PlayfulLayerKind.clinicalTruth);
    expect(result.layers.first.text, 'Seek urgent medical review now.');
    expect(result.layers.last.kind, PlayfulLayerKind.companion);
  });

  test('urgent clinical playfulness is opt-in', () {
    final result = compose(clinicalTruth: truth(ClinicalTruthSeverity.urgent));
    expect(result.layers, hasLength(1));
    expect(result.playfulApplied, isFalse);
  });

  test('user can explicitly keep playful companion in urgent context', () {
    final result = compose(
      clinicalTruth: truth(ClinicalTruthSeverity.urgent),
      preferences: const PlayfulPresentationPreferences(
        tone: PlayfulTone.playful,
        allowInUrgent: true,
      ),
    );
    expect(result.layers, hasLength(2));
    expect(result.playfulApplied, isTrue);
  });

  test('serious clinical context needs separate opt-in', () {
    final blocked = compose(isSeriousClinical: true);
    expect(blocked.playfulApplied, isFalse);
    final allowed = compose(
      isSeriousClinical: true,
      preferences: const PlayfulPresentationPreferences(
        allowInSeriousClinical: true,
      ),
    );
    expect(allowed.playfulApplied, isTrue);
  });

  test('playful purpose permission is required', () {
    final result = compose(grants: const []);
    expect(result.playfulApplied, isFalse);
  });

  test('spicy tone additionally requires intimacy permission', () {
    final playfulGrant =
        grant(RelationshipCapability.playful, 'relationship.playful.support');
    final blocked = compose(
      preferences:
          const PlayfulPresentationPreferences(tone: PlayfulTone.spicy),
      grants: [playfulGrant],
    );
    expect(blocked.playfulApplied, isFalse);

    final allowed = compose(
      preferences:
          const PlayfulPresentationPreferences(tone: PlayfulTone.spicy),
      grants: [
        playfulGrant,
        grant(RelationshipCapability.intimacy, 'relationship.intimacy.support'),
      ],
    );
    expect(allowed.playfulApplied, isTrue);
  });

  test('playful output never replaces clinical truth', () {
    final result = compose(
      clinicalTruth: truth(ClinicalTruthSeverity.reviewRecommended),
      preferences: const PlayfulPresentationPreferences(
        tone: PlayfulTone.funny,
        allowInSeriousClinical: true,
      ),
    );
    expect(result.renderedText.startsWith('Seek urgent medical review now.'),
        isTrue);
  });
}
