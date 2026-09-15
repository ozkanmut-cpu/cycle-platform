import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated ids are unique across roles and representative seeds', () {
    const generator = PersonaGenerator();
    final ids = <String>{};
    for (var seed = 0; seed < 100; seed++) {
      expect(ids.add(generator.patient(seed).id), isTrue);
      expect(ids.add(generator.partner(seed).id), isTrue);
      expect(ids.add(generator.doctor(seed).id), isTrue);
    }
  });
}
