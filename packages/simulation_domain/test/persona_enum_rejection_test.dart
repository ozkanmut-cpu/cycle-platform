import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('malformed core enum is rejected', () {
    const generator = PersonaGenerator();
    final json = generator.patient(88).toJson();
    final core = (json['core'] as Map<String, Object?>)..['healthLiteracy'] = 'expert-plus';
    json['core'] = core;
    expect(() => SimulationPersona.fromJson(json), throwsFormatException);
  });
}
