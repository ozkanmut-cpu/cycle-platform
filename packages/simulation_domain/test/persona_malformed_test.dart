import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('unsupported enum value is rejected instead of normalized', () {
    const generator = PersonaGenerator();
    final json = generator.doctor(12).toJson()..['reviewStyle'] = 'magic';
    expect(() => SimulationPersona.fromJson(json), throwsFormatException);
  });
}
