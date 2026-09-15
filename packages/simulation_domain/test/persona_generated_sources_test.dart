import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated patient baseline declares manual source', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      expect(generator.patient(seed).healthDataSources, const ['manual']);
    }
  });
}
