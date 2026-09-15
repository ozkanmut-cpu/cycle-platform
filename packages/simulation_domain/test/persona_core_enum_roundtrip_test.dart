import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared core enum dimensions round-trip exactly', () {
    const generator = PersonaGenerator();
    final core = generator.patient(44).core;
    final restored = PersonaCore.fromJson(core.toJson());
    expect(restored.healthLiteracy, core.healthLiteracy);
    expect(restored.digitalLiteracy, core.digitalLiteracy);
    expect(restored.privacySensitivity, core.privacySensitivity);
    expect(restored.dataDensity, core.dataDensity);
    expect(restored.wearableUse, core.wearableUse);
    expect(restored.loggingBehaviour, core.loggingBehaviour);
  });
}
