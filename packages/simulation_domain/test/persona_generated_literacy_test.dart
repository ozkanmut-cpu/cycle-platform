import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated literacy dimensions always use supported states', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 100; seed++) {
      final core = generator.patient(seed).core;
      expect(LiteracyLevel.values, contains(core.healthLiteracy));
      expect(LiteracyLevel.values, contains(core.digitalLiteracy));
    }
  });
}
