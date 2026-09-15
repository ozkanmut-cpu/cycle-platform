import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('fixture manifest contains partner boundary coverage', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    final partners = (manifest['fixtures'] as List).where((item) => (item as Map<String, dynamic>)['role'] == 'partner');
    expect(partners, isNotEmpty);
  });
}
