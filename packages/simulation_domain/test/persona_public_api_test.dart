import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona domain types are available through public package API', () {
    expect(const PersonaGenerator(), isA<PersonaGenerator>());
    expect(PersonaRole.values.length, 3);
  });
}
