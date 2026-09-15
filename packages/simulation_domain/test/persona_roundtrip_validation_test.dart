import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('fromJson returns already validated personas', () {
    const generator = PersonaGenerator();
    for (final json in <Map<String, Object?>>[generator.patient(1).toJson(), generator.partner(2).toJson(), generator.doctor(3).toJson()]) {
      final restored = SimulationPersona.fromJson(json);
      expect(restored.validate, returnsNormally);
    }
  });
}
