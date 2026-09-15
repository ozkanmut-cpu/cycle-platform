import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('decoded persona rejects empty expected mental model', () {
    const generator = PersonaGenerator();
    final json = generator.patient(42).toJson();
    final core = (json['core'] as Map<String, Object?>)..['expectedMentalModel'] = '';
    json['core'] = core;
    expect(() => SimulationPersona.fromJson(json), throwsArgumentError);
  });
}
