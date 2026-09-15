import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('representative seed set remains deterministic', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 100; seed++) {
      expect(jsonEncode(generator.patient(seed).toJson()), jsonEncode(generator.patient(seed).toJson()));
      expect(jsonEncode(generator.partner(seed).toJson()), jsonEncode(generator.partner(seed).toJson()));
      expect(jsonEncode(generator.doctor(seed).toJson()), jsonEncode(generator.doctor(seed).toJson()));
    }
  });
}
