import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('persona documentation pins missingness and permission semantics', () {
    final text = File('../../docs/SIMULATION_PERSONAS.md').readAsStringSync();
    expect(text, contains('Missingness is explicit and never means zero or normal'));
    expect(text, contains('Generic sharing and relationship categories remain distinct'));
  });
}
