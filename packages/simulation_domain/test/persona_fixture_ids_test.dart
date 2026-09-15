import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('high-risk fixture ids are unique', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    final fixtures = (manifest['fixtures'] as List).cast<Map<String, dynamic>>();
    final ids = fixtures.map((item) => item['id']).toList();
    expect(ids.toSet().length, ids.length);
  });
}
