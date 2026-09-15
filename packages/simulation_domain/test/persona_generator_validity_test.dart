import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated personas validate across representative seeds', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 50; seed++) {
      expect(() => generator.patient(seed).validate(), returnsNormally);
      expect(() => generator.partner(seed).validate(), returnsNormally);
      expect(() => generator.doctor(seed).validate(), returnsNormally);
    }
  });
}
