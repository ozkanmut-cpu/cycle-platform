import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('baseline generator keeps wearable off until cohort profile overrides it', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      expect(generator.patient(seed).core.wearableUse, WearableUse.none);
    }
  });
}
