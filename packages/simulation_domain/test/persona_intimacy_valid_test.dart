import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('explicit intimacy grant permits intimacy preference', () {
    const generator = PersonaGenerator();
    final base = generator.partner(44);
    final persona = PartnerPersona(id: base.id, core: base.core, relationshipType: base.relationshipType, sharingGrants: base.sharingGrants, relationshipCategoryGrants: const ['relationshipIntelligence', 'intimacy'], playfulEnabled: true, intimacyEnabled: true, boundarySensitivity: base.boundarySensitivity);
    expect(persona.validate, returnsNormally);
  });
}
