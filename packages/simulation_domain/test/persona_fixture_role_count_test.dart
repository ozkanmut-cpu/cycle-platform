import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('representative fixture manifest includes patient partner doctor', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    final roles = (manifest['fixtures'] as List).map((item) => (item as Map<String, dynamic>)['role']).toSet();
    expect(roles, containsAll(<String>{'patient', 'partner', 'doctor'}));
  });
}
