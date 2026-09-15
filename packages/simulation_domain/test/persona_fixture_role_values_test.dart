import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('fixture roles use only supported persona role names', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    for (final fixture in (manifest['fixtures'] as List).cast<Map<String, dynamic>>()) {
      expect(<String>{'patient', 'partner', 'doctor'}, contains(fixture['role']));
    }
  });
}
