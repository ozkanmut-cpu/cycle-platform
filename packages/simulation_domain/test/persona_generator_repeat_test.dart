import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('repeated generation does not depend on previous calls', () {
    const generator = PersonaGenerator();
    final expected = jsonEncode(generator.patient(17).toJson());
    generator.doctor(999);
    generator.partner(123);
    expect(jsonEncode(generator.patient(17).toJson()), expected);
  });
}
