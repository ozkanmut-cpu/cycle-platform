import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  const generator = PersonaGenerator();

  test('unknown role fails safely', () {
    final json = generator.patient(7).toJson()..['role'] = 'caregiver';
    expect(() => SimulationPersona.fromJson(json), throwsFormatException);
  });

  test('age outside adult simulation boundary is rejected', () {
    final patient = generator.patient(8);
    final invalidCore = PersonaCore(age: 17, healthLiteracy: patient.core.healthLiteracy, digitalLiteracy: patient.core.digitalLiteracy, accessibilityNeeds: patient.core.accessibilityNeeds, privacySensitivity: patient.core.privacySensitivity, dataDensity: patient.core.dataDensity, wearableUse: patient.core.wearableUse, loggingBehaviour: patient.core.loggingBehaviour, goals: patient.core.goals, fears: patient.core.fears, expectedMentalModel: patient.core.expectedMentalModel);
    expect(invalidCore.validate, throwsArgumentError);
  });
}
