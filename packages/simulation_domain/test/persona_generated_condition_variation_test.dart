import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('seeded patient generator includes condition and medication variation', () {
    const generator = PersonaGenerator();
    final conditionStates = <bool>{};
    final medicationStates = <bool>{};
    for (var seed = 0; seed < 100; seed++) {
      final patient = generator.patient(seed);
      conditionStates.add(patient.conditions.isNotEmpty);
      medicationStates.add(patient.medications.isNotEmpty);
    }
    expect(conditionStates, {true, false});
    expect(medicationStates, {true, false});
  });
}
