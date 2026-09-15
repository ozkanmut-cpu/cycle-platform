import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated patient always has explicit health profile fields', () {
    const generator = PersonaGenerator();
    final patient = generator.patient(47);
    expect(patient.healthDataSources, isNotEmpty);
    expect(patient.toJson()['cycleLifeStage'], isNotNull);
    expect(patient.toJson()['missingnessPattern'], isNotNull);
    expect(patient.toJson()['symptomBurden'], isA<int>());
  });
}
