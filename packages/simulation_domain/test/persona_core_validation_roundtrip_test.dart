import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('restored core retains a valid mental model and age', () {
    const generator = PersonaGenerator();
    final restored = PersonaCore.fromJson(generator.patient(4).core.toJson());
    expect(restored.validate, returnsNormally);
  });
}
