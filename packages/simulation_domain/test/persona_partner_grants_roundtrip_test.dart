import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('partner generic and category grants round-trip independently', () {
    const generator = PersonaGenerator();
    final partner = generator.partner(31);
    final restored = SimulationPersona.fromJson((jsonDecode(jsonEncode(partner.toJson())) as Map).cast<String, Object?>()) as PartnerPersona;
    expect(restored.sharingGrants, partner.sharingGrants);
    expect(restored.relationshipCategoryGrants, partner.relationshipCategoryGrants);
  });
}
