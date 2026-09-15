import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('high-risk fixture manifest covers every role and key risks', () {
    final json = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    expect(json['schemaVersion'], 1);
    final fixtures = (json['fixtures'] as List).cast<Map<String, dynamic>>();
    expect(fixtures.map((item) => item['role']).toSet(), containsAll(<String>{'patient', 'partner', 'doctor'}));
    final dimensions = fixtures.expand((item) => (item['dimensions'] as List).cast<String>()).toSet();
    expect(dimensions, containsAll(<String>{'low-health-literacy', 'large-text', 'privacy-sensitive', 'no-wearable', 'wearable-heavy', 'conflicting-data', 'high-caseload', 'complex-care'}));
  });
}
