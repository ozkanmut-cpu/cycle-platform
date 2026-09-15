import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('playful preference never creates intimacy grant in generated personas', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 100; seed++) {
      final partner = generator.partner(seed);
      if (partner.playfulEnabled) {
        expect(partner.relationshipCategoryGrants, isNot(contains('intimacy')));
      }
    }
  });
}
