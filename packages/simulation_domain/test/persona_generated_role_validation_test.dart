import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('representative generated role batches validate', () {
    const generator = PersonaGenerator();
    for (var seed = 0; seed < 100; seed++) {
      generator.patient(seed).validate();
      generator.partner(seed).validate();
      generator.doctor(seed).validate();
    }
  });
}
