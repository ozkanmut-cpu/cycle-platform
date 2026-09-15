import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared core JSON preserves explicit dimensions', () {
    const generator = PersonaGenerator();
    final core = generator.patient(606).core;
    final restored = PersonaCore.fromJson(core.toJson());
    expect(restored.age, core.age);
    expect(restored.healthLiteracy, core.healthLiteracy);
    expect(restored.digitalLiteracy, core.digitalLiteracy);
    expect(restored.privacySensitivity, core.privacySensitivity);
    expect(restored.loggingBehaviour, core.loggingBehaviour);
  });
}
