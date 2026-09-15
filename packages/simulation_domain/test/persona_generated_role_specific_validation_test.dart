import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('role-specific validators accept their generated baseline', () {
    const generator = PersonaGenerator();
    expect(generator.patient(60).validate, returnsNormally);
    expect(generator.partner(61).validate, returnsNormally);
    expect(generator.doctor(62).validate, returnsNormally);
  });
}
