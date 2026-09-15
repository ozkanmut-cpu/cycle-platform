import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('smoke actor payloads use persona schema constant', () {
    const generator = PersonaGenerator();
    for (final persona in <SimulationPersona>[generator.patient(20260915), generator.partner(20260916), generator.doctor(20260917)]) {
      expect(persona.toJson()['schemaVersion'], personaSchemaVersion);
    }
  });
}
