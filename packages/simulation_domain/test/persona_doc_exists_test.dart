import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('persona methodology document is checked in', () {
    expect(File('../../docs/SIMULATION_PERSONAS.md').existsSync(), isTrue);
  });
}
