import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('every generated role exposes a valid shared core', () {
    const generator = PersonaGenerator();
    for (final persona in <SimulationPersona>[generator.patient(1), generator.partner(2), generator.doctor(3)]) {
      expect(persona.core, isA<PersonaCore>());
      expect(persona.core.validate, returnsNormally);
    }
  });
}
