import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('doctor persona does not imply patient access permissions', () {
    const generator = PersonaGenerator();
    final json = generator.doctor(64).toJson();
    expect(json, isNot(contains('permissions')));
    expect(json, isNot(contains('patientAccess')));
  });
}
