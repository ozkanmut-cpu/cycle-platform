import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated accessibility needs remain explicit list values', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      expect(generator.patient(seed).core.accessibilityNeeds, everyElement(isA<String>()));
    }
  });
}
