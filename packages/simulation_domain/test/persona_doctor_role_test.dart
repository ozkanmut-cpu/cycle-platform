import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('doctor persona models workflow context rather than patient observations', () {
    const generator = PersonaGenerator();
    final json = generator.doctor(303).toJson();
    expect(json, containsPair('role', 'doctor'));
    expect(json, isNot(contains('symptomBurden')));
    expect(json, isNot(contains('missingnessPattern')));
  });
}
