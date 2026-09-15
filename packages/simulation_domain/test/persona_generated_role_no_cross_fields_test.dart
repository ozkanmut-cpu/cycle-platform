import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated roles keep role-specific fields isolated', () {
    const generator = PersonaGenerator();
    expect(generator.patient(1).toJson(), isNot(contains('relationshipType')));
    expect(generator.partner(2).toJson(), isNot(contains('specialtyProfile')));
    expect(generator.doctor(3).toJson(), isNot(contains('cycleLifeStage')));
  });
}
