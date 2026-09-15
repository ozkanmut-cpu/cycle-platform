import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generator output always uses current persona schema version', () {
    const generator = PersonaGenerator();
    for (final persona in <SimulationPersona>[generator.patient(72), generator.partner(73), generator.doctor(74)]) {
      expect(persona.toJson()['schemaVersion'], personaSchemaVersion);
    }
  });
}
