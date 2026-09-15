import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated playful variation never changes baseline grants', () {
    const generator = PersonaGenerator();
    List<String>? grants;
    List<String>? categories;
    for (var seed = 0; seed < 50; seed++) {
      final partner = generator.partner(seed);
      grants ??= partner.sharingGrants;
      categories ??= partner.relationshipCategoryGrants;
      expect(partner.sharingGrants, grants);
      expect(partner.relationshipCategoryGrants, categories);
    }
  });
}
