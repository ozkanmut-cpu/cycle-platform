import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated privacy sensitivity always uses supported state', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 100; seed++) {
      expect(PrivacySensitivity.values, contains(generator.patient(seed).core.privacySensitivity));
    }
  });
}
