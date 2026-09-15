import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('zero seed remains a stable explicit persona identity', () {
    const generator = PersonaGenerator();
    expect(generator.patient(0).id, 'patient-0');
    expect(generator.partner(0).id, 'partner-0');
    expect(generator.doctor(0).id, 'doctor-0');
  });
}
