import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared core list dimensions round-trip in order', () {
    const generator = PersonaGenerator();
    final core = generator.patient(43).core;
    final restored = PersonaCore.fromJson(core.toJson());
    expect(restored.accessibilityNeeds, core.accessibilityNeeds);
    expect(restored.goals, core.goals);
    expect(restored.fears, core.fears);
  });
}
