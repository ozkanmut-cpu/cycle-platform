import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona smoke payload is valid machine-readable JSON', () {
    const generator = PersonaGenerator();
    final encoded = jsonEncode(<String, Object?>{'schemaVersion': personaSchemaVersion, 'seed': 1, 'personas': <Map<String, Object?>>[generator.patient(1).toJson(), generator.partner(2).toJson(), generator.doctor(3).toJson()]});
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], personaSchemaVersion);
    expect((decoded['personas'] as List).length, 3);
  });
}
