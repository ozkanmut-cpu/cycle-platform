import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated data density uses supported non-high baseline states', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      final density = generator.patient(seed).core.dataDensity;
      expect(DataDensity.values, contains(density));
      expect(density, isNot(DataDensity.high));
    }
  });
}
