import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('seeded generation is stable for every persona role', () {
    const generator = PersonaGenerator();
    for (final factory in <SimulationPersona Function(int)>[generator.patient, generator.partner, generator.doctor]) {
      final first = factory(20260915);
      final second = factory(20260915);
      expect(second.id, first.id);
      expect(jsonEncode(second.toJson()), jsonEncode(first.toJson()));
    }
  });
}
