import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generator methods do not share mutable random state', () {
    const generator = PersonaGenerator();
    final before = jsonEncode(generator.doctor(35).toJson());
    for (var seed = 0; seed < 20; seed++) { generator.patient(seed); generator.partner(seed); }
    expect(jsonEncode(generator.doctor(35).toJson()), before);
  });
}
