import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('high-risk manifest describes coverage rather than hidden random seeds', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    expect(manifest, isNot(contains('seed')));
  });
}
