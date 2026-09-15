import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated partner grants remain narrow and explicit', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      final partner = generator.partner(seed);
      expect(partner.sharingGrants, const ['relationship']);
      expect(partner.relationshipCategoryGrants, const ['relationshipIntelligence']);
    }
  });
}
