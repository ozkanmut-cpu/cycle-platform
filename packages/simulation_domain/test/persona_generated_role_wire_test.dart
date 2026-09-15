import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated persona role serializes as string', () {
    const generator = PersonaGenerator();
    expect(generator.partner(99).toJson()['role'], isA<String>());
  });
}
