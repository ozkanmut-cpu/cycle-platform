import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('representative fixtures cover required high-risk usability classes', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    final dimensions = (manifest['fixtures'] as List).expand((item) => ((item as Map<String, dynamic>)['dimensions'] as List).cast<String>()).toSet();
    expect(dimensions, containsAll(<String>{'low-health-literacy', 'large-text', 'privacy-sensitive', 'no-wearable', 'wearable-heavy', 'polypharmacy', 'conflicting-data', 'revoke-ready', 'intimacy-off', 'high-caseload', 'complex-care', 'high-data-volume'}));
  });
}
