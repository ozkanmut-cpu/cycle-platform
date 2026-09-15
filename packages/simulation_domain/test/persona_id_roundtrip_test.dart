import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona id survives deserialization exactly', () {
    const generator = PersonaGenerator();
    for (final persona in <SimulationPersona>[generator.patient(50), generator.partner(51), generator.doctor(52)]) {
      expect(SimulationPersona.fromJson(persona.toJson()).id, persona.id);
    }
  });
}
