import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona role survives deserialization exactly', () {
    const generator = PersonaGenerator();
    for (final persona in <SimulationPersona>[generator.patient(53), generator.partner(54), generator.doctor(55)]) {
      expect(SimulationPersona.fromJson(persona.toJson()).role, persona.role);
    }
  });
}
