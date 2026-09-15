import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('expected mental model serializes as string', () {
    const generator = PersonaGenerator();
    expect(generator.patient(97).core.toJson()['expectedMentalModel'], isA<String>());
  });
}
