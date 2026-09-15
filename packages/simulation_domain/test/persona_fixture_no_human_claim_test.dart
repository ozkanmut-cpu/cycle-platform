import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('persona documentation states synthetic evidence boundary', () {
    final text = File('../../docs/SIMULATION_PERSONAS.md').readAsStringSync();
    expect(text, contains('not claims about real patients'));
    expect(text, contains('Human usability evidence remains separate'));
  });
}
