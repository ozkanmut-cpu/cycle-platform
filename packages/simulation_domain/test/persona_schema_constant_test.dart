import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona schema constant is available through public package API', () {
    expect(personaSchemaVersion, greaterThan(0));
  });
}
