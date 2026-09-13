import 'package:cycle_clinical_domain/cycle_clinical_domain.dart';
import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('bodyPelvicPainTaxonomy', () {
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
  });
}
