import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared core enum wire values serialize as names', () {
    const generator = PersonaGenerator();
    final json = generator.patient(93).core.toJson();
    for (final key in <String>['healthLiteracy', 'digitalLiteracy', 'privacySensitivity', 'dataDensity', 'wearableUse', 'loggingBehaviour']) {
      expect(json[key], isA<String>());
    }
  });
}
