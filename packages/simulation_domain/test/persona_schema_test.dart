import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona schema version is explicit and pinned', () {
    expect(personaSchemaVersion, 1);
    expect(const PersonaGenerator().patient(1).toJson()['schemaVersion'], personaSchemaVersion);
  });
}
