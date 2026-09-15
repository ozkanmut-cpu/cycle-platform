import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('decoded patient rejects invalid symptom burden', () {
    const generator = PersonaGenerator();
    final json = generator.patient(40).toJson()..['symptomBurden'] = -1;
    expect(() => SimulationPersona.fromJson(json), throwsArgumentError);
  });
}
