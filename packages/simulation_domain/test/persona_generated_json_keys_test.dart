import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated persona envelope begins with explicit identity contract', () {
    const generator = PersonaGenerator();
    for (final persona in <SimulationPersona>[generator.patient(1), generator.partner(2), generator.doctor(3)]) {
      expect(persona.toJson().keys.take(4).toList(), ['schemaVersion', 'role', 'id', 'core']);
    }
  });
}
