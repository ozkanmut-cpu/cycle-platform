import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('implausible high-density sparse no-source core is rejected', () {
    const core = PersonaCore(age: 40, healthLiteracy: LiteracyLevel.medium, digitalLiteracy: LiteracyLevel.medium, accessibilityNeeds: [], privacySensitivity: PrivacySensitivity.medium, dataDensity: DataDensity.high, wearableUse: WearableUse.none, loggingBehaviour: LoggingBehaviour.sparse, goals: ['understand-health'], fears: ['misinterpretation'], expectedMentalModel: 'Cycle labels uncertainty.');
    expect(core.validate, throwsArgumentError);
  });
}
