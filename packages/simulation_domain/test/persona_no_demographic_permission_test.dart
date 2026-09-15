import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('partner permissions do not derive from literacy traits', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      final partner = generator.partner(seed);
      expect(partner.sharingGrants, const ['relationship']);
      expect(partner.relationshipCategoryGrants, const ['relationshipIntelligence']);
    }
  });
}
