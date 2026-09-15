import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('every high-risk fixture has id role and dimensions', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    for (final fixture in (manifest['fixtures'] as List).cast<Map<String, dynamic>>()) {
      expect(fixture['id'], isA<String>());
      expect(fixture['role'], isA<String>());
      expect(fixture['dimensions'], isA<List>());
      expect(fixture['dimensions'], isNotEmpty);
    }
  });
}
