import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated partner relationship types use supported states', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      expect(RelationshipType.values, contains(generator.partner(seed).relationshipType));
    }
  });
}
