import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated partner boundary sensitivity uses supported states', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      expect(BoundarySensitivity.values, contains(generator.partner(seed).boundarySensitivity));
    }
  });
}
