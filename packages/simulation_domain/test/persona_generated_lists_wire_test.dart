import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona list wire values remain JSON arrays', () {
    const generator = PersonaGenerator();
    final patient = generator.patient(94).toJson();
    final partner = generator.partner(95).toJson();
    expect(patient['conditions'], isA<List<String>>());
    expect(patient['medications'], isA<List<String>>());
    expect(partner['sharingGrants'], isA<List<String>>());
    expect(partner['relationshipCategoryGrants'], isA<List<String>>());
  });
}
