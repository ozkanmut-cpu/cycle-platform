import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('accessibility needs survive JSON round-trip', () {
    const core = PersonaCore(age: 70, healthLiteracy: LiteracyLevel.low, digitalLiteracy: LiteracyLevel.low, accessibilityNeeds: ['largeText', 'screenReader'], privacySensitivity: PrivacySensitivity.high, dataDensity: DataDensity.low, wearableUse: WearableUse.none, loggingBehaviour: LoggingBehaviour.regular, goals: ['understand-health'], fears: ['privacy'], expectedMentalModel: 'Cycle explains uncertainty.');
    final persona = PatientPersona(id: 'patient-accessibility', core: core, cycleLifeStage: CycleLifeStage.menopause, conditions: const [], medications: const [], symptomBurden: 2, missingnessPattern: MissingnessPattern.sporadic, healthDataSources: const ['manual']);
    persona.validate();
    final restored = SimulationPersona.fromJson((jsonDecode(jsonEncode(persona.toJson())) as Map).cast<String, Object?>()) as PatientPersona;
    expect(restored.core.accessibilityNeeds, ['largeText', 'screenReader']);
  });
}
