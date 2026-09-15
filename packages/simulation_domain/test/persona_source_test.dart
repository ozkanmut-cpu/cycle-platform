import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated patient always declares its data source', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 25; seed++) {
      expect(generator.patient(seed).healthDataSources, isNotEmpty);
    }
  });
}
