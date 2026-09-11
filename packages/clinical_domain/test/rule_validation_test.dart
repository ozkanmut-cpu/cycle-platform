import 'package:cycle_clinical_domain/cycle_clinical_domain.dart';
import 'package:test/test.dart';

void main() {
  const validator = SymptomRoutingRuleValidator();
  final guideline = GuidelineVersion(
    identifier: 'test-guideline',
    version: '1.0.0',
    effectiveFrom: DateTime.utc(2026, 1, 1),
  );

  ConditionPack pack(String id, Set<String> symptoms) => ConditionPack(
        id: id,
        schemaVersion: 1,
        title: id,
        guideline: guideline,
        symptomKeys: symptoms,
      );

  test('validates positive routing and stable tie ordering', () {
    final fixture = RoutingValidationFixture(
      id: 'routing-tie',
      guidelineIdentifier: 'test-guideline',
      guidelineVersion: '1.0.0',
      report: const SymptomReport(symptomKeys: {'pain'}),
      packs: [
        pack('b', {'pain'}),
        pack('a', {'pain'})
      ],
      expectedConfidence: RoutingConfidence.high,
      expectedCandidateIds: const ['a', 'b'],
    );

    final result = validator.validate(fixture);
    expect(result.status, RuleValidationStatus.passed);
    expect(result.reason, RuleValidationReason.passed);
    expect(result.toJson(), {
      'fixtureId': 'routing-tie',
      'status': 'passed',
      'reason': 'passed',
    });
  });

  test('keeps unknown information explicit', () {
    final fixture = RoutingValidationFixture(
      id: 'insufficient',
      guidelineIdentifier: 'test-guideline',
      guidelineVersion: '1.0.0',
      report: const SymptomReport(
        symptomKeys: {},
        unknownKeys: {' Bleeding ', 'PAIN'},
      ),
      packs: [
        pack('a', {'pain'})
      ],
      expectedConfidence: RoutingConfidence.insufficientInformation,
      expectedCandidateIds: const [],
      expectedMissingInformation: const {'bleeding', 'pain'},
    );

    expect(validator.validate(fixture).status, RuleValidationStatus.passed);
  });

  test('fails deterministically on guideline version mismatch', () {
    final fixture = RoutingValidationFixture(
      id: 'version-mismatch',
      guidelineIdentifier: 'test-guideline',
      guidelineVersion: '2.0.0',
      report: const SymptomReport(symptomKeys: {'pain'}),
      packs: [
        pack('a', {'pain'})
      ],
      expectedConfidence: RoutingConfidence.high,
      expectedCandidateIds: const ['a'],
    );

    final first = validator.validate(fixture);
    final second = validator.validate(fixture);
    expect(first.status, RuleValidationStatus.failed);
    expect(first.reason, RuleValidationReason.guidelineVersionMismatch);
    expect(second.toJson(), first.toJson());
  });

  test('equivalent symptom input ordering produces the same result', () {
    final packs = [
      pack('a', {'pain', 'bleeding'})
    ];
    RoutingValidationFixture fixture(Set<String> symptoms) =>
        RoutingValidationFixture(
          id: 'ordering',
          guidelineIdentifier: 'test-guideline',
          guidelineVersion: '1.0.0',
          report: SymptomReport(symptomKeys: symptoms),
          packs: packs,
          expectedConfidence: RoutingConfidence.high,
          expectedCandidateIds: const ['a'],
        );

    expect(
      validator.validate(fixture({'pain', 'bleeding'})).toJson(),
      validator.validate(fixture({'bleeding', 'pain'})).toJson(),
    );
  });
}
