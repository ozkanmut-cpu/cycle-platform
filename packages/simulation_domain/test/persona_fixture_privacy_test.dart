import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('high-risk fixtures include privacy-sensitive scenarios', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    final dimensions = (manifest['fixtures'] as List).expand((item) => ((item as Map<String, dynamic>)['dimensions'] as List)).toSet();
    expect(dimensions, contains('privacy-sensitive'));
  });
}
