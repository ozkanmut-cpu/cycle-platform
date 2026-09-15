import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('patient traits do not declare derived clinical conclusions', () {
    const generator = PersonaGenerator();
    final json = generator.patient(34).toJson();
    expect(json, contains('conditions'));
    expect(json, isNot(contains('diagnosisConfidence')));
    expect(json, isNot(contains('clinicalRecommendation')));
  });
}
