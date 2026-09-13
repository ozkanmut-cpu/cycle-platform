import 'package:cycle_clinical_domain/cycle_clinical_domain.dart';
import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('bodyPelvicPainTaxonomy', () {
    test('exposes stable taxonomy version metadata', () {
      expect(bodyPelvicPainTaxonomy.schemaVersion, 1);
      expect(bodyPelvicPainTaxonomy.catalogVersion, '2026.1');
      expect(
        () => PainRegionTaxonomy(const [], schemaVersion: 0),
        throwsA(isA<PainMapValidationException>()),
      );
    });

    test('orders and looks up regions deterministically', () {
      final ids = bodyPelvicPainTaxonomy.regions.map((e) => e.id).toList();
      expect(ids, orderedEquals([...ids]..sort()));
      expect(bodyPelvicPainTaxonomy.findById(' PELVIS-LEFT ')?.laterality,
          PainLaterality.left);
      expect(bodyPelvicPainTaxonomy.findById('pelvis-midline')?.laterality,
          PainLaterality.midline);
    });

    test('routes multiple selected regions without diagnosing', () {
      final result = const PainMapRouter().route(
        selection: const PainLocationSelection(
          state: DataState.yes,
          regionIds: {'pelvis-left', 'flank-right'},
        ),
        taxonomy: bodyPelvicPainTaxonomy,
      );
      expect(result.regionIds, ['flank-right', 'pelvis-left']);
      expect(result.symptomKeys,
          containsAll(['pelvic pain', 'left pelvic pain', 'flank pain']));
    });

    test('preserves unknown and not-recorded without fake normal data', () {
      for (final state in [DataState.unknown, DataState.notRecorded]) {
        final result = const PainMapRouter().route(
          selection: PainLocationSelection(state: state),
          taxonomy: bodyPelvicPainTaxonomy,
        );
        expect(result.state, state);
        expect(result.regionIds, isEmpty);
        expect(result.symptomKeys, isEmpty);
      }
    });

    test('rejects malformed taxonomy and ambiguous missing selections', () {
      expect(
        () => PainRegionTaxonomy(const [
          PainRegionDefinition(
              id: 'same',
              title: 'One',
              group: PainRegionGroup.pelvis,
              laterality: PainLaterality.none,
              routingKeys: {'pelvic pain'}),
          PainRegionDefinition(
              id: 'same',
              title: 'Two',
              group: PainRegionGroup.pelvis,
              laterality: PainLaterality.left,
              routingKeys: {'pelvic pain'}),
        ]),
        throwsA(isA<PainMapValidationException>()),
      );
      expect(
        () => const PainMapRouter().route(
          selection: const PainLocationSelection(
            state: DataState.unknown,
            regionIds: {'pelvis-left'},
          ),
          taxonomy: bodyPelvicPainTaxonomy,
        ),
        throwsA(isA<PainMapValidationException>()),
      );
    });

    test('rejects invalid parent/laterality relationships', () {
      expect(
        () => PainRegionTaxonomy(const [
          PainRegionDefinition(
            id: 'pelvis-generalized',
            title: 'Pelvis',
            group: PainRegionGroup.pelvis,
            laterality: PainLaterality.none,
            routingKeys: {'pelvic pain'},
          ),
          PainRegionDefinition(
            id: 'abdomen-left',
            title: 'Left abdomen',
            group: PainRegionGroup.abdomen,
            laterality: PainLaterality.left,
            parentId: 'pelvis-generalized',
            routingKeys: {'lower abdominal pain'},
          ),
        ]),
        throwsA(isA<PainMapValidationException>()),
      );
    });

    test('supports bilateral pelvic routing explicitly', () {
      final result = const PainMapRouter().route(
        selection: const PainLocationSelection(
          state: DataState.yes,
          regionIds: {'pelvis-bilateral'},
        ),
        taxonomy: bodyPelvicPainTaxonomy,
      );
      expect(result.symptomKeys,
          containsAll(['pelvic pain', 'bilateral pelvic pain']));
      expect(bodyPelvicPainTaxonomy.findById('pelvis-bilateral')?.laterality,
          PainLaterality.bilateral);
    });

    test('rejects parent cycles deterministically', () {
      expect(
        () => PainRegionTaxonomy(const [
          PainRegionDefinition(
              id: 'a',
              title: 'A',
              group: PainRegionGroup.pelvis,
              laterality: PainLaterality.left,
              parentId: 'b',
              routingKeys: {'pelvic pain'}),
          PainRegionDefinition(
              id: 'b',
              title: 'B',
              group: PainRegionGroup.pelvis,
              laterality: PainLaterality.left,
              parentId: 'a',
              routingKeys: {'pelvic pain'}),
        ]),
        throwsA(isA<PainMapValidationException>()),
      );
    });

    test('feeds routing keys into existing symptom-first router', () {
      final pain = const PainMapRouter().route(
        selection: const PainLocationSelection(
          state: DataState.yes,
          regionIds: {'pelvis-generalized'},
        ),
        taxonomy: bodyPelvicPainTaxonomy,
      );
      final routed = const SymptomFirstRouter().route(
        report: SymptomReport(symptomKeys: pain.symptomKeys.toSet()),
        packs: ConditionCatalog(conditionCatalogDefinitions).packs,
      );

      expect(routed.hasCandidates, isTrue);
      expect(routed.matches.map((match) => match.pack.id),
          contains('endometriosis'));
      expect(routed.missingInformation, isEmpty);
    });
  });
}
