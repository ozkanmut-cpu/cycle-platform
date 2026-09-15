import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('doctor persona models clinician workflow without embedding a patient', () {
    const generator = PersonaGenerator();
    final json = generator.doctor(79).toJson();
    expect(json, isNot(contains('patient')));
    expect(json, isNot(contains('observations')));
  });
}
