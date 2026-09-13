import 'condition_pack.dart';

final GuidelineVersion _catalogGuideline = GuidelineVersion(
  identifier: 'cycle-condition-catalog',
  version: '2026.1',
  effectiveFrom: DateTime.utc(2026, 9, 13),
);

const ClinicalEvidenceRef _niceNg88Evidence = ClinicalEvidenceRef(
  sourceId: 'nice-ng88',
  summary: 'NICE heavy menstrual bleeding guideline provenance.',
);

const ClinicalEvidenceRef _catalogBaselineEvidence = ClinicalEvidenceRef(
  sourceId: 'cycle-catalog-baseline-2026.1',
  summary: 'Curated symptom-routing metadata; not a diagnostic rule.',
);

final List<ConditionPack> initialConditionCatalogDefinitions = List.unmodifiable([
  ConditionPack(
    id: 'adenomyosis',
    schemaVersion: 1,
    title: 'Adenomyosis',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'heavy menstrual bleeding',
      'painful periods',
      'pelvic pain',
      'pelvic tenderness',
    },
    evidence: const [_niceNg88Evidence],
  ),
  ConditionPack(
    id: 'bacterial-vaginosis',
    schemaVersion: 1,
    title: 'Bacterial vaginosis',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'vaginal discharge',
      'vaginal odor',
      'vaginal irritation',
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'dysmenorrhea',
    schemaVersion: 1,
    title: 'Dysmenorrhea',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'painful periods',
      'pelvic cramping',
      'lower abdominal pain',
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'endometrial-polyp',
    schemaVersion: 1,
    title: 'Endometrial polyp',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'intermenstrual bleeding',
      'irregular bleeding',
      'heavy menstrual bleeding',
    },
    evidence: const [_niceNg88Evidence],
  ),
  ConditionPack(
    id: 'endometriosis',
    schemaVersion: 1,
    title: 'Endometriosis',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'pelvic pain',
      'painful periods',
      'pain during sex',
      'pain with bowel movements',
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'functional-ovarian-cyst',
    schemaVersion: 1,
    title: 'Functional ovarian cyst',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'pelvic pain',
      'lower abdominal pain',
      'pelvic pressure',
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'iron-deficiency-anemia',
    schemaVersion: 1,
    title: 'Iron deficiency anemia',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'fatigue',
      'weakness',
      'shortness of breath',
      'dizziness',
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'pelvic-inflammatory-disease',
    schemaVersion: 1,
    title: 'Pelvic inflammatory disease',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'pelvic pain',
      'lower abdominal pain',
      'fever',
      'abnormal vaginal discharge',
      'pain during sex',
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'polycystic-ovary-syndrome',
    schemaVersion: 1,
    title: 'Polycystic ovary syndrome',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'irregular periods',
      'infrequent periods',
      'acne',
      'excess hair growth',
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'uterine-fibroids',
    schemaVersion: 1,
    title: 'Uterine fibroids',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'heavy menstrual bleeding',
      'pelvic pressure',
      'pelvic pain',
      'abdominal mass',
    },
    evidence: const [_niceNg88Evidence],
  ),
  ConditionPack(
    id: 'urinary-tract-infection',
    schemaVersion: 1,
    title: 'Urinary tract infection',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'painful urination',
      'urinary frequency',
      'urinary urgency',
      'lower abdominal pain',
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'vulvovaginal-candidiasis',
    schemaVersion: 1,
    title: 'Vulvovaginal candidiasis',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'vaginal itching',
      'vaginal irritation',
      'vaginal discharge',
      'painful urination',
    },
    evidence: const [_catalogBaselineEvidence],
  ),
]);
