import 'condition_pack.dart';
import 'condition_catalog_definitions.dart';

final GuidelineVersion _catalogGuideline = GuidelineVersion(
  identifier: 'cycle-condition-catalog',
  version: '2026.1',
  effectiveFrom: DateTime.utc(2026, 9, 13),
);

const ClinicalEvidenceRef _catalogBaselineEvidence = ClinicalEvidenceRef(
  sourceId: 'cycle-catalog-baseline-2026.1',
  summary: 'Curated symptom-routing metadata; not a diagnostic rule.',
);

final List<ConditionPack> conditionCatalogExpansionDefinitions =
    List.unmodifiable([
  _pack('bartholin-cyst', 'Bartholin cyst',
      {'vulvar lump', 'vulvar pain', 'pain while walking'}),
  _pack('cervical-ectropion', 'Cervical ectropion',
      {'postcoital bleeding', 'vaginal discharge', 'intermenstrual bleeding'}),
  _pack('chronic-pelvic-pain', 'Chronic pelvic pain',
      {'pelvic pain', 'lower abdominal pain', 'pain during sex'}),
  _pack('ectopic-pregnancy', 'Ectopic pregnancy',
      {'missed periods', 'pelvic pain', 'vaginal bleeding', 'shoulder pain'}),
  _pack('interstitial-cystitis', 'Interstitial cystitis',
      {'bladder pain', 'urinary frequency', 'urinary urgency', 'pelvic pain'}),
  _pack('lichen-sclerosus', 'Lichen sclerosus',
      {'vulvar itching', 'vulvar pain', 'skin change'}),
  _pack('miscarriage', 'Miscarriage',
      {'vaginal bleeding', 'pelvic cramping', 'lower abdominal pain'}),
  _pack('ovarian-torsion', 'Ovarian torsion',
      {'sudden pelvic pain', 'nausea', 'vomiting'}),
  _pack('pyelonephritis', 'Pyelonephritis',
      {'fever', 'flank pain', 'painful urination', 'nausea'}),
  _pack(
      'recurrent-urinary-tract-infection',
      'Recurrent urinary tract infection',
      {'painful urination', 'urinary frequency', 'urinary urgency'}),
  _pack('vulvar-dermatitis', 'Vulvar dermatitis',
      {'vulvar itching', 'vulvar irritation', 'skin change'}),
  _pack('vulvar-lichen-planus', 'Vulvar lichen planus',
      {'vulvar pain', 'vulvar burning', 'vaginal discharge', 'skin change'}),
]);

final List<ConditionPack> conditionCatalogExpansion2Definitions =
    List.unmodifiable([
  _pack(
      'bacterial-urinary-tract-infection',
      'Bacterial urinary tract infection',
      {'painful urination', 'urinary frequency', 'urinary urgency'}),
  _pack('chronic-endometritis', 'Chronic endometritis',
      {'pelvic pain', 'abnormal uterine bleeding', 'vaginal discharge'}),
  _pack('cystocele', 'Cystocele',
      {'vaginal bulge', 'pelvic pressure', 'difficulty emptying bladder'}),
  _pack('endocervical-polyp', 'Endocervical polyp',
      {'postcoital bleeding', 'intermenstrual bleeding', 'vaginal discharge'}),
  _pack('genital-warts', 'Genital warts',
      {'genital lesions', 'genital itching', 'genital discomfort'}),
  _pack('hemorrhagic-ovarian-cyst', 'Hemorrhagic ovarian cyst',
      {'pelvic pain', 'sudden pelvic pain', 'lower abdominal pain'}),
  _pack('mittelschmerz', 'Mittelschmerz',
      {'midcycle pelvic pain', 'one-sided pelvic pain'}),
  _pack('pelvic-congestion-syndrome', 'Pelvic congestion syndrome',
      {'chronic pelvic pain', 'pelvic heaviness', 'pain during sex'}),
  _pack('rectocele', 'Rectocele',
      {'vaginal bulge', 'pelvic pressure', 'difficulty with bowel movements'}),
  _pack('urethritis', 'Urethritis',
      {'painful urination', 'urethral irritation', 'urinary frequency'}),
  _pack('vaginal-prolapse', 'Vaginal prolapse',
      {'vaginal bulge', 'pelvic pressure', 'pelvic discomfort'}),
  _pack('vulvar-cyst', 'Vulvar cyst',
      {'vulvar lump', 'vulvar discomfort', 'vulvar pain'}),
]);

final List<ConditionPack> conditionCatalogExpansion3Definitions =
    List.unmodifiable([
  _pack('cervical-cancer', 'Cervical cancer',
      {'postcoital bleeding', 'abnormal vaginal bleeding', 'pelvic pain'}),
  _pack('endometrial-cancer', 'Endometrial cancer',
      {'postmenopausal bleeding', 'abnormal uterine bleeding', 'pelvic pain'}),
  _pack('hydrosalpinx', 'Hydrosalpinx',
      {'pelvic pain', 'lower abdominal pain', 'vaginal discharge'}),
  _pack('ovarian-cancer', 'Ovarian cancer', {
    'persistent bloating',
    'pelvic pain',
    'early satiety',
    'urinary frequency'
  }),
  _pack(
      'ovarian-hyperstimulation-syndrome',
      'Ovarian hyperstimulation syndrome',
      {'abdominal bloating', 'pelvic pain', 'nausea', 'shortness of breath'}),
  _pack('pelvic-abscess', 'Pelvic abscess',
      {'pelvic pain', 'fever', 'abnormal vaginal discharge'}),
  _pack('pudendal-neuralgia', 'Pudendal neuralgia',
      {'pelvic pain', 'vulvar pain', 'pain with sitting'}),
  _pack('tubo-ovarian-abscess', 'Tubo-ovarian abscess',
      {'pelvic pain', 'fever', 'lower abdominal pain'}),
  _pack('urethral-diverticulum', 'Urethral diverticulum',
      {'painful urination', 'urethral pain', 'urinary leakage'}),
  _pack('vaginal-cancer', 'Vaginal cancer',
      {'abnormal vaginal bleeding', 'vaginal discharge', 'pelvic pain'}),
  _pack('vulvar-abscess', 'Vulvar abscess',
      {'vulvar lump', 'vulvar pain', 'fever'}),
  _pack('vulvar-cancer', 'Vulvar cancer',
      {'vulvar lump', 'vulvar itching', 'vulvar pain', 'skin change'}),
]);

final List<ConditionPack> conditionCatalogDefinitions = List.unmodifiable([
  ...initialConditionCatalogDefinitions,
  ...conditionCatalogExpansionDefinitions,
  ...conditionCatalogExpansion2Definitions,
  ...conditionCatalogExpansion3Definitions,
]);

ConditionPack _pack(String id, String title, Set<String> symptomKeys) =>
    ConditionPack(
      id: id,
      schemaVersion: 1,
      title: title,
      guideline: _catalogGuideline,
      symptomKeys: symptomKeys,
      evidence: const [_catalogBaselineEvidence],
    );
