import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('fixture manifest contains multiple patient usability risks', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    final patients = (manifest['fixtures'] as List).where((item) => (item as Map<String, dynamic>)['role'] == 'patient');
    expect(patients.length, greaterThanOrEqualTo(2));
  });
}
