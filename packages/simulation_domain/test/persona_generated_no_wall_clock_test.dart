import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona generation has no wall-clock field', () {
    const generator = PersonaGenerator();
    final payload = jsonEncode(generator.patient(56).toJson());
    expect(payload, isNot(contains('createdAt')));
    expect(payload, isNot(contains('generatedAt')));
  });
}
