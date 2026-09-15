import 'dart:convert';
import 'dart:io';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('fixture manifest schema matches persona schema constant', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['schemaVersion'], personaSchemaVersion);
  });
}
