import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('symptom burden outside zero to ten is rejected', () {
    const generator = PersonaGenerator();
    final base = generator.patient(20);
    final invalid = PatientPersona(id: base.id, core: base.core, cycleLifeStage: base.cycleLifeStage, conditions: base.conditions, medications: base.medications, symptomBurden: 11, missingnessPattern: base.missingnessPattern, healthDataSources: base.healthDataSources);
    expect(invalid.validate, throwsArgumentError);
  });
}
