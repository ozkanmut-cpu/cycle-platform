import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('every persona JSON includes schema role id and core', () {
    const generator = PersonaGenerator();
    for (final persona in <SimulationPersona>[generator.patient(1), generator.partner(2), generator.doctor(3)]) {
      final json = persona.toJson();
      expect(json['schemaVersion'], personaSchemaVersion);
      expect(json['role'], persona.role.name);
      expect(json['id'], persona.id);
      expect(json['core'], isA<Map<String, Object?>>());
    }
  });
}
