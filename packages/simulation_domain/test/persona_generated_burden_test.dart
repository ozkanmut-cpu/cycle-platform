import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated symptom burden stays bounded', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 100; seed++) {
      expect(generator.patient(seed).symptomBurden, inInclusiveRange(0, 10));
    }
  });
}
