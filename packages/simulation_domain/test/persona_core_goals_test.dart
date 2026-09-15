import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('goals fears and expected mental model remain explicit', () {
    const generator = PersonaGenerator();
    final core = generator.patient(18).core;
    final restored = PersonaCore.fromJson(core.toJson());
    expect(restored.goals, core.goals);
    expect(restored.fears, core.fears);
    expect(restored.expectedMentalModel, core.expectedMentalModel);
  });
}
