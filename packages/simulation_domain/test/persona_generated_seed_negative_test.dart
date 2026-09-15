import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('negative seed remains deterministic and explicitly identified', () {
    const generator = PersonaGenerator();
    expect(generator.patient(-1).id, 'patient--1');
    expect(jsonEncode(generator.patient(-1).toJson()), jsonEncode(generator.patient(-1).toJson()));
  });
}
