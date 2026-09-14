import 'relationship_policy.dart';

enum PlayfulTone { plain, warm, romantic, funny, playful, flirty, spicy }

enum ClinicalTruthSeverity { informational, reviewRecommended, urgent }

enum PlayfulLayerKind { clinicalTruth, companion }

class ClinicalTruthLayer {
  ClinicalTruthLayer({
    required this.id,
    required this.text,
    required this.severity,
    required this.createdAt,
  }) {
    if (id.trim().isEmpty || text.trim().isEmpty) {
      throw const RelationshipPolicyException(
        'clinical truth id/text must not be blank',
      );
    }
  }

  final String id;
  final String text;
  final ClinicalTruthSeverity severity;
  final DateTime createdAt;
}

class PlayfulPresentationPreferences {
  const PlayfulPresentationPreferences({
    this.enabled = true,
    this.tone = PlayfulTone.warm,
    this.allowInSensitive = false,
    this.allowInSeriousClinical = false,
    this.allowInUrgent = false,
  });

  final bool enabled;
  final PlayfulTone tone;
  final bool allowInSensitive;
  final bool allowInSeriousClinical;
  final bool allowInUrgent;
}

class PlayfulLayer {
  const PlayfulLayer({
    required this.kind,
    required this.text,
    required this.tone,
  });

  final PlayfulLayerKind kind;
  final String text;
  final PlayfulTone tone;
}

class PlayfulComposition {
  PlayfulComposition({
    required Iterable<PlayfulLayer> layers,
    required this.playfulApplied,
  }) : layers = List.unmodifiable(layers);

  final List<PlayfulLayer> layers;
  final bool playfulApplied;

  String get renderedText => layers.map((e) => e.text).join('\n\n');
}

class PlayfulEngine {
  const PlayfulEngine({
    this.firewall = const RelationshipPermissionFirewall(),
  });

  final RelationshipPermissionFirewall firewall;

  PlayfulComposition compose({
    required String ownerId,
    required String recipientId,
    required String category,
    required DateTime at,
    required String companionText,
    required PlayfulPresentationPreferences preferences,
    required Iterable<RelationshipCategoryGrant> grants,
    ClinicalTruthLayer? clinicalTruth,
    bool isSensitive = false,
    bool isSeriousClinical = false,
  }) {
    final layers = <PlayfulLayer>[];
    if (clinicalTruth != null) {
      layers.add(
        PlayfulLayer(
          kind: PlayfulLayerKind.clinicalTruth,
          text: clinicalTruth.text,
          tone: PlayfulTone.plain,
        ),
      );
    }

    if (!preferences.enabled || companionText.trim().isEmpty) {
      return PlayfulComposition(layers: layers, playfulApplied: false);
    }

    final permissionCategory = 'relationship.playful.$category';
    final playfulAllowed = firewall
        .evaluate(
          request: RelationshipAccessRequest(
            ownerId: ownerId,
            recipientId: recipientId,
            category: permissionCategory,
            capability: RelationshipCapability.playful,
            at: at,
          ),
          grants: grants,
        )
        .allowed;
    if (!playfulAllowed) {
      return PlayfulComposition(layers: layers, playfulApplied: false);
    }

    final urgent = clinicalTruth?.severity == ClinicalTruthSeverity.urgent;
    final serious = isSeriousClinical ||
        clinicalTruth?.severity == ClinicalTruthSeverity.reviewRecommended ||
        urgent;
    if (urgent && !preferences.allowInUrgent) {
      return PlayfulComposition(layers: layers, playfulApplied: false);
    }
    if (serious && !urgent && !preferences.allowInSeriousClinical) {
      return PlayfulComposition(layers: layers, playfulApplied: false);
    }
    if (isSensitive && !serious && !preferences.allowInSensitive) {
      return PlayfulComposition(layers: layers, playfulApplied: false);
    }

    if (preferences.tone == PlayfulTone.spicy) {
      final intimacyAllowed = firewall
          .evaluate(
            request: RelationshipAccessRequest(
              ownerId: ownerId,
              recipientId: recipientId,
              category: 'relationship.intimacy.$category',
              capability: RelationshipCapability.intimacy,
              at: at,
            ),
            grants: grants,
          )
          .allowed;
      if (!intimacyAllowed) {
        return PlayfulComposition(layers: layers, playfulApplied: false);
      }
    }

    layers.add(
      PlayfulLayer(
        kind: PlayfulLayerKind.companion,
        text: companionText.trim(),
        tone: preferences.tone,
      ),
    );
    return PlayfulComposition(layers: layers, playfulApplied: true);
  }
}
