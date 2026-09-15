import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('age remains exact through shared core serialization', () {
    const generator = PersonaGenerator();
    final core = generator.patient(1234).core;
    expect(PersonaCore.fromJson(core.toJson()).age, core.age);
  });
}
