import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated cores always contain goals fears and mental model', () {
    const generator = PersonaGenerator();
    for (final core in <PersonaCore>[generator.patient(1).core, generator.partner(2).core, generator.doctor(3).core]) {
      expect(core.goals, isNotEmpty);
      expect(core.fears, isNotEmpty);
      expect(core.expectedMentalModel, isNotEmpty);
    }
  });
}
