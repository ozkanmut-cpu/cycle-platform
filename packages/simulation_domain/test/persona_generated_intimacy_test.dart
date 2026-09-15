import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated partner personas never silently opt into intimacy', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 100; seed++) {
      expect(generator.partner(seed).intimacyEnabled, isFalse);
      expect(generator.partner(seed).relationshipCategoryGrants, isNot(contains('intimacy')));
    }
  });
}
