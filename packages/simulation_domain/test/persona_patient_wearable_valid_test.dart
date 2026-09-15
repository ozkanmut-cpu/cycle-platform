import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('wearable patient is valid with explicit source', () {
    const generator = PersonaGenerator();
    final base = generator.patient(67);
    final core = PersonaCore(age: base.core.age, healthLiteracy: base.core.healthLiteracy, digitalLiteracy: base.core.digitalLiteracy, accessibilityNeeds: base.core.accessibilityNeeds, privacySensitivity: base.core.privacySensitivity, dataDensity: DataDensity.high, wearableUse: WearableUse.heavy, loggingBehaviour: base.core.loggingBehaviour, goals: base.core.goals, fears: base.core.fears, expectedMentalModel: base.core.expectedMentalModel);
    final patient = PatientPersona(id: base.id, core: core, cycleLifeStage: base.cycleLifeStage, conditions: base.conditions, medications: base.medications, symptomBurden: base.symptomBurden, missingnessPattern: MissingnessPattern.conflicting, healthDataSources: const ['healthConnect']);
    expect(patient.validate, returnsNormally);
  });
}
