import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('privacy sensitivity round-trip does not create permissions', () {
    const generator = PersonaGenerator();
    final patient = generator.patient(505);
    final restored = SimulationPersona.fromJson((jsonDecode(jsonEncode(patient.toJson())) as Map).cast<String, Object?>()) as PatientPersona;
    expect(restored.core.privacySensitivity, patient.core.privacySensitivity);
    expect(restored.toJson(), isNot(contains('sharingGrants')));
  });
}
