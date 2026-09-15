import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona role wire names remain stable', () {
    expect(PersonaRole.values.map((value) => value.name).toList(), ['patient', 'partner', 'doctor']);
  });
}
