import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('decoded partner cannot enable intimacy without explicit grant', () {
    const generator = PersonaGenerator();
    final json = generator.partner(39).toJson()..['intimacyEnabled'] = true;
    expect(() => SimulationPersona.fromJson(json), throwsArgumentError);
  });
}
