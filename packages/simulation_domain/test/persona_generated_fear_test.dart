import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated shared fear targets interpretation risk', () {
    const generator = PersonaGenerator();
    expect(generator.patient(37).core.fears, const ['misinterpretation']);
  });
}
