import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('fixture dimensions do not claim real participant evidence', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    final text = jsonEncode(manifest).toLowerCase();
    expect(text, isNot(contains('participant-result')));
    expect(text, isNot(contains('human-result')));
  });
}
