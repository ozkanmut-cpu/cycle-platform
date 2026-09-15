import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('missing persona schema version fails safely', () {
    const generator = PersonaGenerator();
    final json = generator.patient(10).toJson()..remove('schemaVersion');
    expect(() => SimulationPersona.fromJson(json), throwsFormatException);
  });
}
