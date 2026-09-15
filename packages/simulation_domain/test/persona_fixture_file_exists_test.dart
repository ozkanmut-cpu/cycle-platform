import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('high-risk persona fixture manifest is checked in', () {
    expect(File('test/fixtures/persona_high_risk.json').existsSync(), isTrue);
  });
}
