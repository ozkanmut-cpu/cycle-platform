import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('role-specific generators cannot silently change actor role', () {
    const generator = PersonaGenerator();
    expect(generator.patient(1).role, PersonaRole.patient);
    expect(generator.partner(1).role, PersonaRole.partner);
    expect(generator.doctor(1).role, PersonaRole.doctor);
  });
}
