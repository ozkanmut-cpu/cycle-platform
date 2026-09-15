import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('patient health dimensions survive round-trip', () {
    const generator = PersonaGenerator();
    final patient = generator.patient(707);
    final restored = SimulationPersona.fromJson((jsonDecode(jsonEncode(patient.toJson())) as Map).cast<String, Object?>()) as PatientPersona;
    expect(restored.cycleLifeStage, patient.cycleLifeStage);
    expect(restored.missingnessPattern, patient.missingnessPattern);
    expect(restored.symptomBurden, patient.symptomBurden);
  });
}
