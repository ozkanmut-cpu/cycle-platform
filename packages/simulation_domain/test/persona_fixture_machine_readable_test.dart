import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('high-risk persona fixture is valid JSON object', () {
    expect(jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()), isA<Map<String, dynamic>>());
  });
}
