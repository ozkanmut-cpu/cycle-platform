import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('same seed remains role-scoped by generated id', () {
    const generator = PersonaGenerator();
    final ids = {generator.patient(5).id, generator.partner(5).id, generator.doctor(5).id};
    expect(ids.length, 3);
  });
}
