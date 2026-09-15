import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('partner persona contains access context but no patient raw data', () {
    const generator = PersonaGenerator();
    final json = generator.partner(78).toJson();
    expect(json, contains('sharingGrants'));
    expect(json, isNot(contains('patientData')));
    expect(json, isNot(contains('observations')));
  });
}
