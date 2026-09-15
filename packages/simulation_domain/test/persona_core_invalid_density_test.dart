import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('source-free sparse core cannot claim high data density', () {
    const core = PersonaCore(age: 35, healthLiteracy: LiteracyLevel.high, digitalLiteracy: LiteracyLevel.high, accessibilityNeeds: [], privacySensitivity: PrivacySensitivity.low, dataDensity: DataDensity.high, wearableUse: WearableUse.none, loggingBehaviour: LoggingBehaviour.sparse, goals: ['understand-health'], fears: ['misinterpretation'], expectedMentalModel: 'Cycle labels uncertainty.');
    expect(core.validate, throwsArgumentError);
  });
}
