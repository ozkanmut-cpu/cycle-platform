enum ClinicalToneMode {
  neutral,
  supportive,
  seriousClinical,
}

class ClinicalToneContext {
  const ClinicalToneContext({
    this.isSensitive = false,
    this.isSeriousClinical = false,
    this.reviewRecommended = false,
    this.urgentReviewRecommended = false,
  });

  final bool isSensitive;
  final bool isSeriousClinical;
  final bool reviewRecommended;
  final bool urgentReviewRecommended;
}

class ClinicalTonePolicy {
  const ClinicalTonePolicy({
    required this.mode,
    required this.allowPlayfulLanguage,
    required this.allowEmoji,
    required this.allowJokes,
    required this.allowCelebratoryPhrasing,
    required this.requireConciseWording,
    required this.requireRespectfulWording,
    required this.requireNonAlarmistWording,
  });

  final ClinicalToneMode mode;
  final bool allowPlayfulLanguage;
  final bool allowEmoji;
  final bool allowJokes;
  final bool allowCelebratoryPhrasing;
  final bool requireConciseWording;
  final bool requireRespectfulWording;
  final bool requireNonAlarmistWording;
}

class ClinicalToneGovernor {
  const ClinicalToneGovernor();

  ClinicalTonePolicy policyFor(ClinicalToneContext context) {
    final serious = context.urgentReviewRecommended ||
        context.reviewRecommended ||
        context.isSeriousClinical;

    if (serious) {
      return const ClinicalTonePolicy(
        mode: ClinicalToneMode.seriousClinical,
        allowPlayfulLanguage: false,
        allowEmoji: false,
        allowJokes: false,
        allowCelebratoryPhrasing: false,
        requireConciseWording: true,
        requireRespectfulWording: true,
        requireNonAlarmistWording: true,
      );
    }

    if (context.isSensitive) {
      return const ClinicalTonePolicy(
        mode: ClinicalToneMode.supportive,
        allowPlayfulLanguage: false,
        allowEmoji: false,
        allowJokes: false,
        allowCelebratoryPhrasing: false,
        requireConciseWording: true,
        requireRespectfulWording: true,
        requireNonAlarmistWording: true,
      );
    }

    return const ClinicalTonePolicy(
      mode: ClinicalToneMode.neutral,
      allowPlayfulLanguage: true,
      allowEmoji: true,
      allowJokes: true,
      allowCelebratoryPhrasing: true,
      requireConciseWording: false,
      requireRespectfulWording: true,
      requireNonAlarmistWording: true,
    );
  }
}
