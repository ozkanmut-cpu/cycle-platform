import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated patient health lists remain string lists', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      final patient = generator.patient(seed);
      expect(patient.conditions, everyElement(isA<String>()));
      expect(patient.medications, everyElement(isA<String>()));
      expect(patient.healthDataSources, everyElement(isA<String>()));
    }
  });
}
