import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('patient missingness is an explicit semantic dimension', () {
    const generator = PersonaGenerator();
    final patient = generator.patient(314);
    expect(patient.toJson()['missingnessPattern'], patient.missingnessPattern.name);
    expect(patient.toJson(), isNot(contains('missingValue')));
  });
}
