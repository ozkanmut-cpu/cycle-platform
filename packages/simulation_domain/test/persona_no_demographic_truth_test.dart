import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('age remains descriptive and does not create truth fields', () {
    const generator = PersonaGenerator();
    for (final seed in <int>[1, 500, 999]) {
      final json = generator.patient(seed).toJson();
      expect(json, contains('core'));
      expect(json, isNot(contains('clinicalTruth')));
      expect(json, isNot(contains('certainty')));
    }
  });
}
