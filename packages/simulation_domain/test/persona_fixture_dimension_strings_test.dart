import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('fixture dimensions contain only nonempty strings', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    for (final fixture in (manifest['fixtures'] as List).cast<Map<String, dynamic>>()) {
      for (final dimension in (fixture['dimensions'] as List).cast<String>()) {
        expect(dimension.trim(), isNotEmpty);
      }
    }
  });
}
