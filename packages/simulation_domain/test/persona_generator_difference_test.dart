import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('different seeds identify distinct generated personas', () {
    const generator = PersonaGenerator();
    final first = generator.patient(100);
    final second = generator.patient(101);
    expect(second.id, isNot(first.id));
    expect(jsonEncode(second.toJson()), isNot(jsonEncode(first.toJson())));
  });
}
