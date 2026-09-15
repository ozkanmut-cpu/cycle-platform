import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared persona core exposes required usability dimensions', () {
    const generator = PersonaGenerator();
    final json = generator.patient(25).core.toJson();
    expect(json.keys, containsAll(<String>{'age', 'healthLiteracy', 'digitalLiteracy', 'accessibilityNeeds', 'privacySensitivity', 'dataDensity', 'wearableUse', 'loggingBehaviour', 'goals', 'fears', 'expectedMentalModel'}));
  });
}
