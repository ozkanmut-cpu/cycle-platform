import 'package:cycle_clinical_domain/cycle_clinical_domain.dart';
import 'package:test/test.dart';

void main() {
  final guideline = GuidelineVersion(
    identifier: 'demo-guideline',
    version: '2026.1',
    effectiveFrom: DateTime.utc(2026, 1, 1),
  );

  final pelvicPain = ConditionPack(
    id: 'pelvic-pain',
    schemaVersion: 1,
    title: 'Pelvic pain',
    guideline: guideline,
    symptomKeys: const {'pelvic pain', 'fever', 'abnormal bleeding'},
    evidence: const [ClinicalEvidenceRef(sourceId: 'demo', summary: 'Representative fixture')],
  );

  final migraine = ConditionPack(
    id: 'migraine',
    schemaVersion: 1,
    title: 'Migraine',
    guideline: guideline,
    symptomKeys: const {'headache', 'nausea', 'light sensitivity'},
  );

  group('SymptomFirstRouter', () {
    const router = SymptomFirstRouter();

    test('returns insufficient information for empty known symptoms', () {
      final result = router.route(
        report: const SymptomReport(symptomKeys: {}, unknownKeys: {'fever'}),
        packs: [pelvicPain, migraine],
      );

      expect(result.confidence, RoutingConfidence.insufficientInformation);
      expect(result.matches, isEmpty);
      expect(result.missingInformation, {'fever'});
    });

    test('ranks matching packs deterministically without diagnosing', () {
      final result = router.route(
        report: const SymptomReport(symptomKeys: {'Pelvic Pain', 'FEVER'}),
        packs: [migraine, pelvicPain],
      );

      expect(result.matches, hasLength(1));
      expect(result.matches.first.pack.id, 'pelvic-pain');
      expect(result.matches.first.matchedSymptoms, {'pelvic pain', 'fever'});
      expect(result.confidence, RoutingConfidence.medium);
    });

    test('uses stable id tie-break when scores are equal', () {
      final a = ConditionPack(
        id: 'a-pack',
        schemaVersion: 1,
        title: 'A',
        guideline: guideline,
        symptomKeys: const {'pain'},
      );
      final b = ConditionPack(
        id: 'b-pack',
        schemaVersion: 1,
        title: 'B',
        guideline: guideline,
        symptomKeys: const {'pain'},
      );

      final result = router.route(
        report: const SymptomReport(symptomKeys: {'pain'}),
        packs: [b, a],
      );

      expect(result.matches.map((e) => e.pack.id), ['a-pack', 'b-pack']);
      expect(result.confidence, RoutingConfidence.high);
    });

    test('preserves guideline version and evidence metadata', () {
      expect(pelvicPain.guideline.identifier, 'demo-guideline');
      expect(pelvicPain.guideline.version, '2026.1');
      expect(pelvicPain.evidence.single.sourceId, 'demo');
      expect(pelvicPain.schemaVersion, 1);
    });
  });
}
