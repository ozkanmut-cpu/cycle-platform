import 'package:cycle_clinical_domain/cycle_clinical_domain.dart';
import 'package:test/test.dart';

void main() {
  group('initialConditionCatalogDefinitions', () {
    test('loads the initial tranche deterministically', () {
      final catalog = ConditionCatalog(initialConditionCatalogDefinitions);

      expect(catalog.length, 36);
      expect(
        catalog.packs.map((pack) => pack.id),
        orderedEquals([
          'abnormal-uterine-bleeding',
          'adenomyosis',
          'amenorrhea',
          'bacterial-vaginosis',
          'bladder-pain-syndrome',
          'cervical-polyp',
          'cervicitis',
          'chlamydia',
          'dysmenorrhea',
          'endometrial-hyperplasia',
          'endometrial-polyp',
          'endometriosis',
          'functional-ovarian-cyst',
          'genital-herpes',
          'genitourinary-syndrome-of-menopause',
          'gonorrhea',
          'iron-deficiency-anemia',
          'menopause',
          'ovarian-endometrioma',
          'overactive-bladder',
          'pelvic-floor-dysfunction',
          'pelvic-inflammatory-disease',
          'pelvic-organ-prolapse',
          'perimenopause',
          'polycystic-ovary-syndrome',
          'premenstrual-dysphoric-disorder',
          'premenstrual-syndrome',
          'primary-ovarian-insufficiency',
          'stress-urinary-incontinence',
          'trichomoniasis',
          'urinary-retention',
          'urinary-tract-infection',
          'uterine-fibroids',
          'vaginismus',
          'vulvodynia',
          'vulvovaginal-candidiasis',
        ]),
      );
    });

    test('preserves stable lookup and provenance metadata', () {
      final catalog = ConditionCatalog(initialConditionCatalogDefinitions);
      final fibroids = catalog.findById(' UTERINE-FIBROIDS ');

      expect(fibroids, isNotNull);
      expect(fibroids!.title, 'Uterine fibroids');
      expect(fibroids.schemaVersion, 1);
      expect(fibroids.guideline.identifier, 'cycle-condition-catalog');
      expect(fibroids.guideline.version, '2026.1');
      expect(
        fibroids.evidence.map((entry) => entry.sourceId),
        contains('nice-ng88'),
      );
    });

    test('routes symptoms to candidates without producing a diagnosis', () {
      final catalog = ConditionCatalog(initialConditionCatalogDefinitions);
      const router = SymptomFirstRouter();

      final result = router.route(
        report: const SymptomReport(
          symptomKeys: {'heavy menstrual bleeding', 'pelvic pressure'},
          unknownKeys: {'fever'},
        ),
        packs: catalog.packs,
      );

      expect(result.hasCandidates, isTrue);
      expect(result.matches.first.pack.id, 'uterine-fibroids');
      expect(result.missingInformation, contains('fever'));
      expect(
        result.matches.every((match) => match.pack.title.isNotEmpty),
        isTrue,
      );
    });

    test('all initial definitions keep non-diagnostic routing metadata', () {
      for (final pack in initialConditionCatalogDefinitions) {
        expect(pack.id, isNotEmpty);
        expect(pack.title, isNotEmpty);
        expect(pack.schemaVersion, greaterThan(0));
        expect(pack.symptomKeys, isNotEmpty);
        expect(pack.guideline.identifier, 'cycle-condition-catalog');
        expect(pack.evidence, isNotEmpty);
      }
    });
  });
}
