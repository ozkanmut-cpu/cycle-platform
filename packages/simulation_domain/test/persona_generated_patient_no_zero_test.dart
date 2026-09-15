import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('patient persona missingness does not synthesize measurement zero', () {
    const generator = PersonaGenerator();
    final json = generator.patient(77).toJson();
    expect(json, contains('missingnessPattern'));
    expect(json, isNot(contains('value')));
    expect(json, isNot(contains('measurement')));
  });
}
