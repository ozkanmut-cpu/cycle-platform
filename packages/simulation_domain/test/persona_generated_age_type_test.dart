import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated ages remain integer values', () {
    const generator = PersonaGenerator();
    expect(generator.patient(85).core.toJson()['age'], isA<int>());
    expect(generator.partner(86).core.toJson()['age'], isA<int>());
    expect(generator.doctor(87).core.toJson()['age'], isA<int>());
  });
}
