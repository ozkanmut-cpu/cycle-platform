import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('empty expected mental model is rejected', () {
    const core = PersonaCore(age: 30, healthLiteracy: LiteracyLevel.medium, digitalLiteracy: LiteracyLevel.medium, accessibilityNeeds: [], privacySensitivity: PrivacySensitivity.medium, dataDensity: DataDensity.low, wearableUse: WearableUse.none, loggingBehaviour: LoggingBehaviour.regular, goals: [], fears: [], expectedMentalModel: '   ');
    expect(core.validate, throwsArgumentError);
  });
}
