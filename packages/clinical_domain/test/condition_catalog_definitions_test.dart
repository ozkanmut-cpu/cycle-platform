import 'package:cycle_clinical_domain/cycle_clinical_domain.dart';
import 'package:test/test.dart';

void main() {
  group('initialConditionCatalogDefinitions', () {
    test('loads the initial tranche deterministically', () {
      final catalog = ConditionCatalog(conditionCatalogDefinitions);

      expect(catalog.length, 78);
      final ids = catalog.packs.map((pack) => pack.id).toList();
      final sortedIds = [...ids]..sort();
      expect(ids, orderedEquals(sortedIds));
      expect(ids.toSet(), hasLength(78));
      expect(
          ids,
          containsAll(<String>{
            'uterine-fibroids',
            'endometriosis',
            'ectopic-pregnancy',
            'ovarian-torsion',
            'vulvar-lichen-planus',
            'pelvic-congestion-syndrome',
            'rectocele',
            'genital-warts',
            'ovarian-cancer',
            'tubo-ovarian-abscess',
            'vulvar-cancer',
            'asherman-syndrome',
            'ovarian-cyst-rupture',
            'vulvar-intraepithelial-neoplasia',
          }));
    });

    test('preserves stable lookup and provenance metadata', () {
      final catalog = ConditionCatalog(conditionCatalogDefinitions);
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
      final catalog = ConditionCatalog(conditionCatalogDefinitions);
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
      for (final pack in conditionCatalogDefinitions) {
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
