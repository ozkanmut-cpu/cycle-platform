import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('coverage manifest does not itself grant product permissions', () {
    final manifest = jsonDecode(File('test/fixtures/persona_high_risk.json').readAsStringSync()) as Map<String, dynamic>;
    expect(manifest, isNot(contains('permissions')));
    expect(manifest, isNot(contains('sharingGrants')));
  });
}
