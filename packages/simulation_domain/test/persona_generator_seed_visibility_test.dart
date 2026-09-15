import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated persona id carries replayable seed identity', () {
    const generator = PersonaGenerator();
    const seed = 20260915;
    expect(generator.patient(seed).id.endsWith('$seed'), isTrue);
  });
}
