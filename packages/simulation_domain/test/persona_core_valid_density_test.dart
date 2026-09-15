import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('intensive manual logging can plausibly support high data density', () {
    const core = PersonaCore(age: 35, healthLiteracy: LiteracyLevel.high, digitalLiteracy: LiteracyLevel.high, accessibilityNeeds: [], privacySensitivity: PrivacySensitivity.low, dataDensity: DataDensity.high, wearableUse: WearableUse.none, loggingBehaviour: LoggingBehaviour.intensive, goals: ['understand-health'], fears: ['misinterpretation'], expectedMentalModel: 'Cycle labels uncertainty.');
    expect(core.validate, returnsNormally);
  });
}
