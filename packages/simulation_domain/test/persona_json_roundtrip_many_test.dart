import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('representative generated set round-trips deterministically', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 25; seed++) {
      for (final persona in <SimulationPersona>[generator.patient(seed), generator.partner(seed), generator.doctor(seed)]) {
        final encoded = jsonEncode(persona.toJson());
        final restored = SimulationPersona.fromJson((jsonDecode(encoded) as Map).cast<String, Object?>());
        expect(jsonEncode(restored.toJson()), encoded);
      }
    }
  });
}
