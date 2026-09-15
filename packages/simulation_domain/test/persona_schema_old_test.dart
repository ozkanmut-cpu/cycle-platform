import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('old persona schema is rejected until migration is explicit', () {
    const generator = PersonaGenerator();
    final json = generator.doctor(71).toJson()..['schemaVersion'] = 0;
    expect(() => SimulationPersona.fromJson(json), throwsFormatException);
  });
}
