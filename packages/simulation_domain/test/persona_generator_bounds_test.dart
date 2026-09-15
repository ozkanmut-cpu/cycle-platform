import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated personas stay inside adult simulation age bounds', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 100; seed++) {
      expect(generator.patient(seed).core.age, inInclusiveRange(18, 110));
      expect(generator.partner(seed).core.age, inInclusiveRange(18, 110));
      expect(generator.doctor(seed).core.age, inInclusiveRange(18, 110));
    }
  });
}
