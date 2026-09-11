import 'package:cycle_fertility_domain/cycle_fertility_domain.dart';
import 'package:test/test.dart';

void main() {
  const validator = PregnancySafetyRuleValidator();
  final provenance = DomainProvenance(
    sourceId: 'fixture-source',
    recordedAt: DateTime.utc(2026, 1, 1),
  );
  final episode = PregnancyEpisode(
    id: 'preg-1',
    startedAt: DateTime.utc(2026, 1, 1),
    dating: PregnancyDating(
      estimatedStartDate: DateTime.utc(2026, 1, 1),
      basis: 'fixture',
      provenance: provenance,
    ),
  );

  PregnancySafetyValidationFixture fixture({
    String version = '1.0.0',
    List<String> expectedRuleIds = const ['review'],
    List<PregnancySafetyDisposition> expectedDispositions =
        const [PregnancySafetyDisposition.reviewRecommended],
    Set<String> expectedEvidenceIds = const {'symptom-1'},
  }) =>
      PregnancySafetyValidationFixture(
        id: 'pregnancy-safety',
        ruleSet: PregnancySafetyRuleSetVersion(
          identifier: 'pregnancy-safety',
          version: version,
        ),
        expectedRuleSet: const PregnancySafetyRuleSetVersion(
          identifier: 'pregnancy-safety',
          version: '1.0.0',
        ),
        episode: episode,
        vitals: const [],
        symptoms: [
          PregnancySymptomObservation(
            symptomKey: 'pain',
            observedAt: DateTime.utc(2026, 1, 2),
            provenance: provenance,
          ),
        ],
        expectedRuleIds: expectedRuleIds,
        expectedDispositions: expectedDispositions,
        expectedEvidenceIds: expectedEvidenceIds,
      );

  test('passes review recommendation with evidence', () {
    final result = validator.validate(
      fixture: fixture(),
      kernel: const _Kernel(
        results: [
          PregnancySafetyRuleResult(
            ruleId: 'review',
            disposition: PregnancySafetyDisposition.reviewRecommended,
            reason: 'Clinical review is recommended.',
            evidenceIds: ['symptom-1'],
          ),
        ],
      ),
    );

    expect(result.status, PregnancyRuleValidationStatus.passed);
    expect(result.toJson()['reason'], 'passed');
  });

  test('passes urgent review outcome', () {
    final result = validator.validate(
      fixture: fixture(
        expectedDispositions: const [
          PregnancySafetyDisposition.urgentReviewRecommended,
        ],
      ),
      kernel: const _Kernel(
        results: [
          PregnancySafetyRuleResult(
            ruleId: 'review',
            disposition: PregnancySafetyDisposition.urgentReviewRecommended,
            reason: 'Urgent clinical review is recommended.',
            evidenceIds: ['symptom-1'],
          ),
        ],
      ),
    );

    expect(result.status, PregnancyRuleValidationStatus.passed);
  });

  test('fails before evaluation on rule-set version mismatch', () {
    final kernel = _CountingKernel();
    final result = validator.validate(
      fixture: fixture(version: '2.0.0'),
      kernel: kernel,
    );

    expect(result.reason, PregnancyRuleValidationReason.ruleSetVersionMismatch);
    expect(kernel.calls, 0);
  });

  test('rejects autonomous treatment directives in rule reason', () {
    final result = validator.validate(
      fixture: fixture(),
      kernel: const _Kernel(
        results: [
          PregnancySafetyRuleResult(
            ruleId: 'review',
            disposition: PregnancySafetyDisposition.reviewRecommended,
            reason: 'Start medication immediately.',
            evidenceIds: ['symptom-1'],
          ),
        ],
      ),
    );

    expect(result.reason, PregnancyRuleValidationReason.unsafeAutonomousAction);
  });

  test('repeated runs are deterministic', () {
    const kernel = _Kernel(
      results: [
        PregnancySafetyRuleResult(
          ruleId: 'review',
          disposition: PregnancySafetyDisposition.reviewRecommended,
          reason: 'Clinical review is recommended.',
          evidenceIds: ['symptom-1'],
        ),
      ],
    );
    final first = validator.validate(fixture: fixture(), kernel: kernel);
    final second = validator.validate(fixture: fixture(), kernel: kernel);
    expect(second.toJson(), first.toJson());
  });
}

class _Kernel implements PregnancySafetyKernel {
  const _Kernel({required this.results});

  final List<PregnancySafetyRuleResult> results;

  @override
  List<PregnancySafetyRuleResult> evaluate({
    required PregnancyEpisode episode,
    required List<PregnancyVitalObservation> vitals,
    required List<PregnancySymptomObservation> symptoms,
  }) =>
      results;
}

class _CountingKernel implements PregnancySafetyKernel {
  int calls = 0;

  @override
  List<PregnancySafetyRuleResult> evaluate({
    required PregnancyEpisode episode,
    required List<PregnancyVitalObservation> vitals,
    required List<PregnancySymptomObservation> symptoms,
  }) {
    calls += 1;
    return const [];
  }
}
