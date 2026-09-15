import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated persona batches decode through schema discriminator', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 25; seed++) {
      expect(SimulationPersona.fromJson(generator.patient(seed).toJson()), isA<PatientPersona>());
      expect(SimulationPersona.fromJson(generator.partner(seed).toJson()), isA<PartnerPersona>());
      expect(SimulationPersona.fromJson(generator.doctor(seed).toJson()), isA<DoctorPersona>());
    }
  });
}
