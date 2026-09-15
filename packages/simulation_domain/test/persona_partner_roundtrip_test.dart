import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('partner boundary dimensions survive round-trip', () {
    const generator = PersonaGenerator();
    final partner = generator.partner(808);
    final restored = SimulationPersona.fromJson((jsonDecode(jsonEncode(partner.toJson())) as Map).cast<String, Object?>()) as PartnerPersona;
    expect(restored.boundarySensitivity, partner.boundarySensitivity);
    expect(restored.sharingGrants, partner.sharingGrants);
    expect(restored.relationshipCategoryGrants, partner.relationshipCategoryGrants);
  });
}
