import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated doctor risk tolerance uses supported states', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      expect(RiskTolerance.values, contains(generator.doctor(seed).riskTolerance));
    }
  });
}
