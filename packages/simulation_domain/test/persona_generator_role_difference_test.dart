import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('same seed produces distinct role payloads', () {
    const generator = PersonaGenerator();
    final payloads = <String>{jsonEncode(generator.patient(26).toJson()), jsonEncode(generator.partner(26).toJson()), jsonEncode(generator.doctor(26).toJson())};
    expect(payloads.length, 3);
  });
}
