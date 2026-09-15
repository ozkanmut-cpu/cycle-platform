import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated stable id is explicit and preserved in JSON', () {
    const generator = PersonaGenerator();
    final persona = generator.patient(76);
    expect(persona.toJson()['id'], persona.id);
  });
}
