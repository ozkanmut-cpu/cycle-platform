import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('each role generator is independently deterministic', () {
    const generator = PersonaGenerator();
    expect(jsonEncode(generator.patient(82).toJson()), jsonEncode(generator.patient(82).toJson()));
    expect(jsonEncode(generator.partner(83).toJson()), jsonEncode(generator.partner(83).toJson()));
    expect(jsonEncode(generator.doctor(84).toJson()), jsonEncode(generator.doctor(84).toJson()));
  });
}
