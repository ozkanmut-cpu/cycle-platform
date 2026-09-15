import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('fixture manifest includes relationship and clinical workload risks', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    final fixtures = (manifest['fixtures'] as List).cast<Map<String, dynamic>>();
    final dimensions = fixtures.expand((item) => (item['dimensions'] as List).cast<String>()).toSet();
    expect(dimensions, containsAll(<String>{'revoke-ready', 'intimacy-off', 'high-caseload', 'high-data-volume'}));
  });
}
