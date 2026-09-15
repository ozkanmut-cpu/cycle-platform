import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('partner exposes relationship grants playful intimacy and boundaries', () {
    const generator = PersonaGenerator();
    final json = generator.partner(23).toJson();
    expect(json.keys, containsAll(<String>{'relationshipType', 'sharingGrants', 'relationshipCategoryGrants', 'playfulEnabled', 'intimacyEnabled', 'boundarySensitivity'}));
  });
}
