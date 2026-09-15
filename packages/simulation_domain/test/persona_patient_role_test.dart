import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('patient persona health traits do not silently create sharing permissions', () {
    const generator = PersonaGenerator();
    final json = generator.patient(101).toJson();
    expect(json, containsPair('role', 'patient'));
    expect(json, isNot(contains('sharingGrants')));
    expect(json, isNot(contains('relationshipCategoryGrants')));
  });
}
