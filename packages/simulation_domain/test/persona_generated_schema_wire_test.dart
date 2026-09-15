import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona schema version serializes as integer', () {
    const generator = PersonaGenerator();
    expect(generator.doctor(100).toJson()['schemaVersion'], isA<int>());
  });
}
