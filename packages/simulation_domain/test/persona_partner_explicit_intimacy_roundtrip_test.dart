import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('explicit intimacy grant and preference survive round-trip', () {
    const generator = PersonaGenerator();
    final base = generator.partner(68);
    final persona = PartnerPersona(id: base.id, core: base.core, relationshipType: base.relationshipType, sharingGrants: base.sharingGrants, relationshipCategoryGrants: const ['relationshipIntelligence', 'intimacy'], playfulEnabled: true, intimacyEnabled: true, boundarySensitivity: BoundarySensitivity.high);
    persona.validate();
    final restored = SimulationPersona.fromJson((jsonDecode(jsonEncode(persona.toJson())) as Map).cast<String, Object?>()) as PartnerPersona;
    expect(restored.intimacyEnabled, isTrue);
    expect(restored.relationshipCategoryGrants, contains('intimacy'));
  });
}
