import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('conditions and medications remain explicit list fields', () {
    const generator = PersonaGenerator();
    final patient = generator.patient(404);
    final restored = SimulationPersona.fromJson((jsonDecode(jsonEncode(patient.toJson())) as Map).cast<String, Object?>()) as PatientPersona;
    expect(restored.conditions, patient.conditions);
    expect(restored.medications, patient.medications);
  });
}
