import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('decoded persona rejects age outside simulation boundary', () {
    const generator = PersonaGenerator();
    final json = generator.doctor(41).toJson();
    final core = (json['core'] as Map<String, Object?>)..['age'] = 12;
    json['core'] = core;
    expect(() => SimulationPersona.fromJson(json), throwsArgumentError);
  });
}
