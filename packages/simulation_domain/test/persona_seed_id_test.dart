import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated ids are stable role plus seed identifiers', () {
    const generator = PersonaGenerator();
    expect(generator.patient(123).id, 'patient-123');
    expect(generator.partner(123).id, 'partner-123');
    expect(generator.doctor(123).id, 'doctor-123');
  });
}
