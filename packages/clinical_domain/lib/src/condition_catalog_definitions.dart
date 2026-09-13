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

final List<ConditionPack> initialConditionCatalogDefinitions =
    List.unmodifiable([
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
  ConditionPack(
    id: 'amenorrhea',
    schemaVersion: 1,
    title: 'Amenorrhea',
    guideline: _catalogGuideline,
    symptomKeys: const {'absent periods', 'missed periods'},
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'abnormal-uterine-bleeding',
    schemaVersion: 1,
    title: 'Abnormal uterine bleeding',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'irregular bleeding',
      'heavy menstrual bleeding',
      'intermenstrual bleeding'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'bladder-pain-syndrome',
    schemaVersion: 1,
    title: 'Bladder pain syndrome',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'bladder pain',
      'urinary frequency',
      'urinary urgency',
      'pelvic pain'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'genitourinary-syndrome-of-menopause',
    schemaVersion: 1,
    title: 'Genitourinary syndrome of menopause',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'vaginal dryness',
      'pain during sex',
      'urinary urgency',
      'vaginal irritation'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'overactive-bladder',
    schemaVersion: 1,
    title: 'Overactive bladder',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'urinary urgency',
      'urinary frequency',
      'nocturia',
      'urge incontinence'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'pelvic-floor-dysfunction',
    schemaVersion: 1,
    title: 'Pelvic floor dysfunction',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'pelvic pressure',
      'pelvic pain',
      'pain during sex',
      'difficulty emptying bladder'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'perimenopause',
    schemaVersion: 1,
    title: 'Perimenopause',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'irregular periods',
      'hot flashes',
      'night sweats',
      'sleep disturbance'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'premenstrual-dysphoric-disorder',
    schemaVersion: 1,
    title: 'Premenstrual dysphoric disorder',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'premenstrual mood change',
      'irritability',
      'depressed mood',
      'anxiety'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'premenstrual-syndrome',
    schemaVersion: 1,
    title: 'Premenstrual syndrome',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'premenstrual symptoms',
      'bloating',
      'breast tenderness',
      'mood change'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'stress-urinary-incontinence',
    schemaVersion: 1,
    title: 'Stress urinary incontinence',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'urine leakage with cough',
      'urine leakage with exercise',
      'urinary leakage'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'vaginismus',
    schemaVersion: 1,
    title: 'Vaginismus',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'pain during penetration',
      'difficulty with penetration',
      'pelvic floor tightening'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'vulvodynia',
    schemaVersion: 1,
    title: 'Vulvodynia',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'vulvar pain',
      'vulvar burning',
      'pain with touch',
      'pain during sex'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'cervical-polyp',
    schemaVersion: 1,
    title: 'Cervical polyp',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'postcoital bleeding',
      'intermenstrual bleeding',
      'vaginal discharge'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'cervicitis',
    schemaVersion: 1,
    title: 'Cervicitis',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'abnormal vaginal discharge',
      'postcoital bleeding',
      'pelvic pain'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'chlamydia',
    schemaVersion: 1,
    title: 'Chlamydia',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'abnormal vaginal discharge',
      'painful urination',
      'pelvic pain'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'endometrial-hyperplasia',
    schemaVersion: 1,
    title: 'Endometrial hyperplasia',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'abnormal uterine bleeding',
      'heavy menstrual bleeding',
      'postmenopausal bleeding'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'genital-herpes',
    schemaVersion: 1,
    title: 'Genital herpes',
    guideline: _catalogGuideline,
    symptomKeys: const {'genital sores', 'genital pain', 'painful urination'},
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'gonorrhea',
    schemaVersion: 1,
    title: 'Gonorrhea',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'abnormal vaginal discharge',
      'painful urination',
      'pelvic pain'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'menopause',
    schemaVersion: 1,
    title: 'Menopause',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'absent periods',
      'hot flashes',
      'night sweats',
      'vaginal dryness'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'ovarian-endometrioma',
    schemaVersion: 1,
    title: 'Ovarian endometrioma',
    guideline: _catalogGuideline,
    symptomKeys: const {'pelvic pain', 'painful periods', 'pain during sex'},
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'pelvic-organ-prolapse',
    schemaVersion: 1,
    title: 'Pelvic organ prolapse',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'pelvic pressure',
      'vaginal bulge',
      'difficulty emptying bladder'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'primary-ovarian-insufficiency',
    schemaVersion: 1,
    title: 'Primary ovarian insufficiency',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'irregular periods',
      'absent periods',
      'hot flashes',
      'vaginal dryness'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'trichomoniasis',
    schemaVersion: 1,
    title: 'Trichomoniasis',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'vaginal discharge',
      'vaginal irritation',
      'painful urination'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
  ConditionPack(
    id: 'urinary-retention',
    schemaVersion: 1,
    title: 'Urinary retention',
    guideline: _catalogGuideline,
    symptomKeys: const {
      'difficulty emptying bladder',
      'weak urine stream',
      'lower abdominal pressure'
    },
    evidence: const [_catalogBaselineEvidence],
  ),
]);
