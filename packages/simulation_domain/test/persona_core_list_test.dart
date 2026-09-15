import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('non-string accessibility entries fail safely', () {
    const generator = PersonaGenerator();
    final json = generator.patient(66).toJson();
    final core = (json['core'] as Map<String, Object?>)..['accessibilityNeeds'] = <Object>[1];
    json['core'] = core;
    expect(() => SimulationPersona.fromJson(json), throwsFormatException);
  });
}
