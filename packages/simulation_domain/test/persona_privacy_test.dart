import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('privacy sensitivity is descriptive and grants stay explicit', () {
    const generator = PersonaGenerator();
    final partner = generator.partner(77);
    expect(partner.core.toJson(), contains('privacySensitivity'));
    expect(partner.toJson(), contains('sharingGrants'));
    expect(partner.core.toJson(), isNot(contains('sharingGrants')));
  });
}
