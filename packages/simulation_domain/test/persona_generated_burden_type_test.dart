import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated symptom burden remains integer', () {
    const generator = PersonaGenerator();
    expect(generator.patient(89).toJson()['symptomBurden'], isA<int>());
  });
}
