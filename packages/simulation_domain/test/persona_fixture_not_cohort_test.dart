import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('persona phase documentation defers cohort stereotype-free coverage', () {
    final text = File('../../docs/SIMULATION_PERSONAS.md').readAsStringSync();
    expect(text, contains('Later cohort work'));
  });
}
