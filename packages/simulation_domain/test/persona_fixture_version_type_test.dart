import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('fixture schema version is numeric', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['schemaVersion'], isA<int>());
  });
}
