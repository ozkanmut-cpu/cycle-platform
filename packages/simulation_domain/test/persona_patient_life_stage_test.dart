import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('patient life stage is explicit and serializable', () {
    const generator = PersonaGenerator();
    final patient = generator.patient(30);
    expect(patient.toJson()['cycleLifeStage'], patient.cycleLifeStage.name);
  });
}
