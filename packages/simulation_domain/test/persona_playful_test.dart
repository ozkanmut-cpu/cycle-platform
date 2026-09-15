import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('playful preference can exist while intimacy remains disabled', () {
    const generator = PersonaGenerator();
    PartnerPersona? playful;
    for (var seed = 0; seed < 20; seed++) {
      final candidate = generator.partner(seed);
      if (candidate.playfulEnabled) { playful = candidate; break; }
    }
    expect(playful, isNotNull);
    expect(playful!.intimacyEnabled, isFalse);
  });
}
