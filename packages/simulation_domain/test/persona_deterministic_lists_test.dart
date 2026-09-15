import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated list ordering is deterministic', () {
    const generator = PersonaGenerator();
    final first = generator.patient(321);
    final second = generator.patient(321);
    expect(jsonEncode(first.conditions), jsonEncode(second.conditions));
    expect(jsonEncode(first.medications), jsonEncode(second.medications));
    expect(jsonEncode(first.healthDataSources), jsonEncode(second.healthDataSources));
  });
}
