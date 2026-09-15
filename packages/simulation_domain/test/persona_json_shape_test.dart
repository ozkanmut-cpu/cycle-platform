import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('role-specific JSON fields do not bleed across personas', () {
    const generator = PersonaGenerator();
    final patient = generator.patient(1).toJson();
    final partner = generator.partner(2).toJson();
    final doctor = generator.doctor(3).toJson();
    expect(patient, contains('cycleLifeStage'));
    expect(patient, isNot(contains('reviewStyle')));
    expect(partner, contains('boundarySensitivity'));
    expect(partner, isNot(contains('symptomBurden')));
    expect(doctor, contains('reviewStyle'));
    expect(doctor, isNot(contains('relationshipType')));
  });
}
