import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('representative high-risk fixture set remains populated', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    expect((manifest['fixtures'] as List).length, greaterThanOrEqualTo(5));
  });
}
