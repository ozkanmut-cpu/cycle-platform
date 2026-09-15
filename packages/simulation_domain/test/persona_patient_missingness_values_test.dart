import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated missingness always uses supported semantic state', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 100; seed++) {
      expect(MissingnessPattern.values, contains(generator.patient(seed).missingnessPattern));
    }
  });
}
