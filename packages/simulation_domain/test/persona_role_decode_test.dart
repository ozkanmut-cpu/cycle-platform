import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('role discriminator restores concrete persona type', () {
    const generator = PersonaGenerator();
    expect(SimulationPersona.fromJson(generator.patient(1).toJson()), isA<PatientPersona>());
    expect(SimulationPersona.fromJson(generator.partner(2).toJson()), isA<PartnerPersona>());
    expect(SimulationPersona.fromJson(generator.doctor(3).toJson()), isA<DoctorPersona>());
  });
}
