import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('nonstring role discriminator fails safely', () {
    const generator = PersonaGenerator();
    final json = generator.patient(5).toJson()..['role'] = 1;
    expect(() => SimulationPersona.fromJson(json), throwsFormatException);
  });
}
