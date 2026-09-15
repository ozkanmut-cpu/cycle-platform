import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('future persona schema is rejected until explicitly supported', () {
    const generator = PersonaGenerator();
    final json = generator.doctor(70).toJson()..['schemaVersion'] = personaSchemaVersion + 1;
    expect(() => SimulationPersona.fromJson(json), throwsFormatException);
  });
}
