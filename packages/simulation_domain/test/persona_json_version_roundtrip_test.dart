import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('restored persona emits current schema version', () {
    const generator = PersonaGenerator();
    final restored = SimulationPersona.fromJson(generator.partner(49).toJson());
    expect(restored.toJson()['schemaVersion'], personaSchemaVersion);
  });
}
