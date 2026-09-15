import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('doctor workload dimensions survive round-trip', () {
    const generator = PersonaGenerator();
    final doctor = generator.doctor(909);
    final restored = SimulationPersona.fromJson((jsonDecode(jsonEncode(doctor.toJson())) as Map).cast<String, Object?>()) as DoctorPersona;
    expect(restored.caseloadPressure, doctor.caseloadPressure);
    expect(restored.reviewStyle, doctor.reviewStyle);
    expect(restored.riskTolerance, doctor.riskTolerance);
  });
}
