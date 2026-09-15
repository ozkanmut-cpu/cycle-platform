import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('persona documentation names CI fixture artifact', () {
    final text = File('../../docs/SIMULATION_PERSONAS.md').readAsStringSync();
    expect(text, contains('simulation-persona-fixtures'));
  });
}
