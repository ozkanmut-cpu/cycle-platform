import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('partner boundary sensitivity is explicit and serializable', () {
    const generator = PersonaGenerator();
    final partner = generator.partner(28);
    expect(partner.toJson()['boundarySensitivity'], partner.boundarySensitivity.name);
  });
}
