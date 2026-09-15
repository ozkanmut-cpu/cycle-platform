import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('persona docs keep human validation explicitly required', () {
    final text = File('../../docs/SIMULATION_PERSONAS.md').readAsStringSync();
    expect(text, contains('#58'));
    expect(text, contains('still required'));
  });
}
