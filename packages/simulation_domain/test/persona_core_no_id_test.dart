import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared core remains identity-neutral', () {
    const generator = PersonaGenerator();
    expect(generator.patient(81).core.toJson(), isNot(contains('id')));
  });
}
