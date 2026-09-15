import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated persona payloads never declare clinical certainty', () {
    const generator = PersonaGenerator();
    for (final persona in <SimulationPersona>[generator.patient(1), generator.partner(2), generator.doctor(3)]) {
      expect(persona.toJson(), isNot(contains('certainty')));
      expect(persona.toJson(), isNot(contains('clinicalTruth')));
    }
  });
}
