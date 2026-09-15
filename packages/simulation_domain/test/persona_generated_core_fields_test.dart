import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated shared core always has explicit usability profile', () {
    const generator = PersonaGenerator();
    final core = generator.patient(48).core.toJson();
    for (final key in <String>['age', 'healthLiteracy', 'digitalLiteracy', 'accessibilityNeeds', 'privacySensitivity', 'dataDensity', 'wearableUse', 'loggingBehaviour', 'goals', 'fears', 'expectedMentalModel']) {
      expect(core, contains(key));
    }
  });
}
