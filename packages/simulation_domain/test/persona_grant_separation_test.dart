import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generic sharing does not imply intimacy', () {
    const generator = PersonaGenerator();
    final partner = generator.partner(99);
    expect(partner.sharingGrants, isNotEmpty);
    expect(partner.relationshipCategoryGrants, isNot(contains('intimacy')));
    expect(partner.intimacyEnabled, isFalse);
  });
}
