import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('schema version belongs to persona envelope not shared core', () {
    const generator = PersonaGenerator();
    expect(generator.patient(58).toJson(), contains('schemaVersion'));
    expect(generator.patient(58).core.toJson(), isNot(contains('schemaVersion')));
  });
}
