import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('patient exposes life stage complexity burden missingness and sources', () {
    const generator = PersonaGenerator();
    final json = generator.patient(24).toJson();
    expect(json.keys, containsAll(<String>{'cycleLifeStage', 'conditions', 'medications', 'symptomBurden', 'missingnessPattern', 'healthDataSources'}));
  });
}
