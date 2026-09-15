import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated patient life stages use supported active stages', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      expect(CycleLifeStage.values, contains(generator.patient(seed).cycleLifeStage));
      expect(generator.patient(seed).cycleLifeStage, isNot(CycleLifeStage.notApplicable));
    }
  });
}
