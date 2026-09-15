import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared core JSON contains only shared usability dimensions', () {
    const generator = PersonaGenerator();
    expect(generator.patient(75).core.toJson().keys.toSet(), <String>{'age', 'healthLiteracy', 'digitalLiteracy', 'accessibilityNeeds', 'privacySensitivity', 'dataDensity', 'wearableUse', 'loggingBehaviour', 'goals', 'fears', 'expectedMentalModel'});
  });
}
