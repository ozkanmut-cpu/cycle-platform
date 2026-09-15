import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('playful false does not invalidate explicit intimacy preference', () {
    const generator = PersonaGenerator();
    final base = generator.partner(69);
    final persona = PartnerPersona(id: base.id, core: base.core, relationshipType: base.relationshipType, sharingGrants: base.sharingGrants, relationshipCategoryGrants: const ['intimacy'], playfulEnabled: false, intimacyEnabled: true, boundarySensitivity: BoundarySensitivity.high);
    expect(persona.validate, returnsNormally);
  });
}
