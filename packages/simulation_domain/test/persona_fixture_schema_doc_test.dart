import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('persona documentation records schema version', () {
    final text = File('../../docs/SIMULATION_PERSONAS.md').readAsStringSync();
    expect(text, contains('schemaVersion: 1'));
  });
}
