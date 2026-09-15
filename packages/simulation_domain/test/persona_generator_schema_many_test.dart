import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated persona schema remains stable across representative seeds', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 100; seed++) {
      expect(generator.patient(seed).toJson()['schemaVersion'], personaSchemaVersion);
      expect(generator.partner(seed).toJson()['schemaVersion'], personaSchemaVersion);
      expect(generator.doctor(seed).toJson()['schemaVersion'], personaSchemaVersion);
    }
  });
}
