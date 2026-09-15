import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated intimacy stays disabled regardless of other partner traits', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 100; seed++) {
      expect(generator.partner(seed).intimacyEnabled, isFalse);
    }
  });
}
