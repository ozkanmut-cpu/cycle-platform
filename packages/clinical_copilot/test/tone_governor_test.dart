import 'package:cycle_clinical_copilot/cycle_clinical_copilot.dart';
import 'package:test/test.dart';

void main() {
  const governor = ClinicalToneGovernor();

  test('neutral context allows normal product tone', () {
    final policy = governor.policyFor(const ClinicalToneContext());

    expect(policy.mode, ClinicalToneMode.neutral);
    expect(policy.allowPlayfulLanguage, isTrue);
    expect(policy.allowEmoji, isTrue);
    expect(policy.requireRespectfulWording, isTrue);
    expect(policy.requireNonAlarmistWording, isTrue);
  });

  test('sensitive context selects supportive restrained tone', () {
    final policy = governor.policyFor(
      const ClinicalToneContext(isSensitive: true),
    );

    expect(policy.mode, ClinicalToneMode.supportive);
    expect(policy.allowPlayfulLanguage, isFalse);
    expect(policy.allowEmoji, isFalse);
    expect(policy.allowJokes, isFalse);
    expect(policy.requireConciseWording, isTrue);
  });

  test('serious clinical context suppresses playful output', () {
    final policy = governor.policyFor(
      const ClinicalToneContext(isSeriousClinical: true),
    );

    expect(policy.mode, ClinicalToneMode.seriousClinical);
    expect(policy.allowPlayfulLanguage, isFalse);
    expect(policy.allowEmoji, isFalse);
    expect(policy.allowJokes, isFalse);
    expect(policy.allowCelebratoryPhrasing, isFalse);
    expect(policy.requireConciseWording, isTrue);
    expect(policy.requireNonAlarmistWording, isTrue);
  });

  test('review recommendation takes precedence over supportive tone', () {
    final policy = governor.policyFor(
      const ClinicalToneContext(
        isSensitive: true,
        reviewRecommended: true,
      ),
    );

    expect(policy.mode, ClinicalToneMode.seriousClinical);
  });

  test('urgent review always forces serious clinical tone', () {
    final policy = governor.policyFor(
      const ClinicalToneContext(
        urgentReviewRecommended: true,
      ),
    );

    expect(policy.mode, ClinicalToneMode.seriousClinical);
    expect(policy.allowPlayfulLanguage, isFalse);
    expect(policy.allowEmoji, isFalse);
  });
}
