import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('partner persona models relationship context rather than patient truth', () {
    const generator = PersonaGenerator();
    final json = generator.partner(202).toJson();
    expect(json, containsPair('role', 'partner'));
    expect(json, isNot(contains('conditions')));
    expect(json, isNot(contains('symptomBurden')));
  });
}
