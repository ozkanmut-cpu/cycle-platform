import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('nonnumeric schema version is rejected', () {
    const generator = PersonaGenerator();
    final json = generator.patient(27).toJson()..['schemaVersion'] = '1';
    expect(() => SimulationPersona.fromJson(json), throwsFormatException);
  });
}
