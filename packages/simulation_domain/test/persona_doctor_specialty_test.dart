import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated doctor specialties use supported profiles', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      expect(SpecialtyProfile.values, contains(generator.doctor(seed).specialtyProfile));
    }
  });
}
