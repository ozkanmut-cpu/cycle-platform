import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('fixture manifest contains multiple doctor workflow risks', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    final doctors = (manifest['fixtures'] as List).where((item) => (item as Map<String, dynamic>)['role'] == 'doctor');
    expect(doctors.length, greaterThanOrEqualTo(2));
  });
}
