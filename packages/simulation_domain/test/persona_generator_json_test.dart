import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated persona payloads are JSON encodable', () {
    const generator = PersonaGenerator();
    for (final persona in <SimulationPersona>[generator.patient(1), generator.partner(2), generator.doctor(3)]) {
      expect(() => jsonEncode(persona.toJson()), returnsNormally);
    }
  });
}
