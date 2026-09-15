import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona smoke seed set is deterministic', () {
    const generator = PersonaGenerator();
    String render() => jsonEncode(<String, Object?>{'schemaVersion': personaSchemaVersion, 'seed': 20260915, 'personas': <Map<String, Object?>>[generator.patient(20260915).toJson(), generator.partner(20260916).toJson(), generator.doctor(20260917).toJson()]});
    expect(render(), render());
  });
}
