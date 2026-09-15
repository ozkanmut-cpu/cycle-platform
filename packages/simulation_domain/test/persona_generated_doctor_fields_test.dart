import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated doctor always has complete workflow profile', () {
    const generator = PersonaGenerator();
    final doctor = generator.doctor(45);
    expect(doctor.toJson()['specialtyProfile'], isNotNull);
    expect(doctor.toJson()['caseloadPressure'], isNotNull);
    expect(doctor.toJson()['riskTolerance'], isNotNull);
    expect(doctor.toJson()['reviewStyle'], isNotNull);
  });
}
