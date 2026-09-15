import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated partner always has explicit relationship and boundary profile', () {
    const generator = PersonaGenerator();
    final partner = generator.partner(46);
    expect(partner.sharingGrants, isNotEmpty);
    expect(partner.relationshipCategoryGrants, isNotEmpty);
    expect(partner.toJson()['relationshipType'], isNotNull);
    expect(partner.toJson()['boundarySensitivity'], isNotNull);
  });
}
