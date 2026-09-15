import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('seeded partner generator includes playful preference variation', () {
    const generator = PersonaGenerator();
    final states = <bool>{};
    for (var seed = 0; seed < 100; seed++) {
      states.add(generator.partner(seed).playfulEnabled);
    }
    expect(states, {true, false});
  });
}
