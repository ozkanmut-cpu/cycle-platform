import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona smoke role ordering is patient partner doctor', () {
    const generator = PersonaGenerator();
    final roles = <PersonaRole>[generator.patient(1).role, generator.partner(2).role, generator.doctor(3).role];
    expect(roles, <PersonaRole>[PersonaRole.patient, PersonaRole.partner, PersonaRole.doctor]);
  });
}
