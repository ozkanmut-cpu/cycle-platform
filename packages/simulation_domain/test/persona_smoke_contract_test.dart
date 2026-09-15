import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('smoke seed can produce one valid actor of every role', () {
    const generator = PersonaGenerator();
    final personas = <SimulationPersona>[generator.patient(20260915), generator.partner(20260916), generator.doctor(20260917)];
    expect(personas.map((persona) => persona.role).toSet(), PersonaRole.values.toSet());
    for (final persona in personas) {
      expect(persona.toJson()['schemaVersion'], personaSchemaVersion);
    }
  });
}
