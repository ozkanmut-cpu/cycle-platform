import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('seeded generator includes both baseline and large-text accessibility states', () {
    const generator = PersonaGenerator();
    final states = <bool>{};
    for (var seed = 0; seed < 100; seed++) {
      states.add(generator.patient(seed).core.accessibilityNeeds.contains('largeText'));
    }
    expect(states, {true, false});
  });
}
