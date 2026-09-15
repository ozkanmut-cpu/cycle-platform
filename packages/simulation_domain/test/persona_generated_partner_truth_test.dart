import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('partner playful preference does not create clinical conclusions', () {
    const generator = PersonaGenerator();
    final json = generator.partner(33).toJson();
    expect(json, contains('playfulEnabled'));
    expect(json, isNot(contains('diagnosis')));
    expect(json, isNot(contains('clinicalTruth')));
  });
}
