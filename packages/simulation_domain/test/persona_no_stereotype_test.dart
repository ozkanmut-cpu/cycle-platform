import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('age does not derive partner permissions', () {
    const generator = PersonaGenerator();
    final young = generator.partner(1);
    final older = generator.partner(1001);
    expect(young.sharingGrants, const ['relationship']);
    expect(older.sharingGrants, const ['relationship']);
    expect(young.relationshipCategoryGrants, const ['relationshipIntelligence']);
    expect(older.relationshipCategoryGrants, const ['relationshipIntelligence']);
  });
}
