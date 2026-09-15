import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('persona documentation rejects demographic stereotype generation', () {
    final text = File('../../docs/SIMULATION_PERSONAS.md').readAsStringSync();
    expect(text, contains('rather than encoding demographic stereotypes'));
  });
}
