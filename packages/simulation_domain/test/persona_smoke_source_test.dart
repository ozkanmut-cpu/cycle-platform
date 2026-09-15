import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('persona smoke runner is checked in', () {
    expect(File('bin/persona_smoke.dart').existsSync(), isTrue);
  });
}
