import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated persona id serializes as string', () {
    const generator = PersonaGenerator();
    expect(generator.patient(98).toJson()['id'], isA<String>());
  });
}
