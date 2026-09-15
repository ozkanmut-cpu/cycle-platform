import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared core remains role-neutral', () {
    const generator = PersonaGenerator();
    expect(generator.patient(80).core.toJson(), isNot(contains('role')));
  });
}
