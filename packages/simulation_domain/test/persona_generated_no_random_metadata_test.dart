import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona payload does not expose mutable random state', () {
    const generator = PersonaGenerator();
    final payload = jsonEncode(generator.partner(57).toJson());
    expect(payload, isNot(contains('randomState')));
    expect(payload, isNot(contains('rng')));
  });
}
