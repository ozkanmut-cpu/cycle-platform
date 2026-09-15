import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated doctor ages stay in configured professional range', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      expect(generator.doctor(seed).core.age, inInclusiveRange(28, 80));
    }
  });
}
