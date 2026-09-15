import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona smoke ids expose their deterministic seeds', () {
    const generator = PersonaGenerator();
    expect(generator.patient(20260915).id, 'patient-20260915');
    expect(generator.partner(20260916).id, 'partner-20260916');
    expect(generator.doctor(20260917).id, 'doctor-20260917');
  });
}
