import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('doctor caseload pressure is explicit and serializable', () {
    const generator = PersonaGenerator();
    final doctor = generator.doctor(29);
    expect(doctor.toJson()['caseloadPressure'], doctor.caseloadPressure.name);
  });
}
