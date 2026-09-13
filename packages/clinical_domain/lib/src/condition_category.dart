enum ConditionCategory {
  menstrualBleeding,
  hormonalMenopause,
  pelvicPainStructural,
  infectiousInflammatory,
  urinaryPelvicFloor,
  vulvovaginalDermatologic,
  pregnancyRelated,
  oncology,
  hematologic,
  uncategorized,
}

ConditionCategory conditionCategoryForId(String id) {
  switch (id.trim().toLowerCase()) {
    case 'abnormal-uterine-bleeding':
    case 'amenorrhea':
    case 'dysmenorrhea':
    case 'endometrial-atrophy':
    case 'endometrial-hyperplasia':
    case 'endometrial-polyp':
    case 'endocervical-polyp':
    case 'cervical-polyp':
    case 'cervical-stenosis':
      return ConditionCategory.menstrualBleeding;
    case 'genitourinary-syndrome-of-menopause':
    case 'menopause':
    case 'perimenopause':
    case 'polycystic-ovary-syndrome':
    case 'premenstrual-dysphoric-disorder':
    case 'premenstrual-syndrome':
    case 'primary-ovarian-insufficiency':
      return ConditionCategory.hormonalMenopause;
    case 'adenomyosis':
    case 'asherman-syndrome':
    case 'chronic-pelvic-pain':
    case 'endometriosis':
    case 'functional-ovarian-cyst':
    case 'hemorrhagic-ovarian-cyst':
    case 'hydrosalpinx':
    case 'mittelschmerz':
    case 'ovarian-cyst-rupture':
    case 'ovarian-endometrioma':
    case 'ovarian-hyperstimulation-syndrome':
    case 'ovarian-torsion':
    case 'pelvic-adhesions':
    case 'pelvic-congestion-syndrome':
    case 'pudendal-neuralgia':
    case 'uterine-fibroids':
      return ConditionCategory.pelvicPainStructural;
    case 'bacterial-vaginosis':
    case 'cervicitis':
    case 'chlamydia':
    case 'chronic-endometritis':
    case 'genital-herpes':
    case 'gonorrhea':
    case 'pelvic-abscess':
    case 'pelvic-inflammatory-disease':
    case 'pyelonephritis':
    case 'trichomoniasis':
    case 'tubo-ovarian-abscess':
    case 'urethritis':
    case 'urinary-tract-infection':
    case 'bacterial-urinary-tract-infection':
    case 'recurrent-urinary-tract-infection':
    case 'vulvar-abscess':
    case 'vulvovaginal-candidiasis':
      return ConditionCategory.infectiousInflammatory;
    case 'bladder-pain-syndrome':
    case 'cystocele':
    case 'interstitial-cystitis':
    case 'overactive-bladder':
    case 'pelvic-floor-dysfunction':
    case 'pelvic-organ-prolapse':
    case 'rectocele':
    case 'stress-urinary-incontinence':
    case 'urethral-diverticulum':
    case 'urinary-retention':
    case 'vaginal-prolapse':
      return ConditionCategory.urinaryPelvicFloor;
    case 'bartholin-cyst':
    case 'cervical-ectropion':
    case 'genital-warts':
    case 'lichen-sclerosus':
    case 'vaginismus':
    case 'vulvar-cyst':
    case 'vulvar-dermatitis':
    case 'vulvar-intraepithelial-neoplasia':
    case 'vulvar-lichen-planus':
    case 'vulvodynia':
      return ConditionCategory.vulvovaginalDermatologic;
    case 'ectopic-pregnancy':
    case 'miscarriage':
      return ConditionCategory.pregnancyRelated;
    case 'cervical-cancer':
    case 'endometrial-cancer':
    case 'ovarian-cancer':
    case 'vaginal-cancer':
    case 'vulvar-cancer':
      return ConditionCategory.oncology;
    case 'iron-deficiency-anemia':
      return ConditionCategory.hematologic;
    default:
      return ConditionCategory.uncategorized;
  }
}

String conditionGroupKey(ConditionCategory category) => switch (category) {
      ConditionCategory.menstrualBleeding => 'menstrual-bleeding',
      ConditionCategory.hormonalMenopause => 'hormonal-menopause',
      ConditionCategory.pelvicPainStructural => 'pelvic-pain-structural',
      ConditionCategory.infectiousInflammatory => 'infectious-inflammatory',
      ConditionCategory.urinaryPelvicFloor => 'urinary-pelvic-floor',
      ConditionCategory.vulvovaginalDermatologic => 'vulvovaginal-dermatologic',
      ConditionCategory.pregnancyRelated => 'pregnancy-related',
      ConditionCategory.oncology => 'oncology',
      ConditionCategory.hematologic => 'hematologic',
      ConditionCategory.uncategorized => 'uncategorized',
    };
