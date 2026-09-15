import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('doctor workflow traits serialize as presentation context only', () {
    const generator = PersonaGenerator();
    final json = generator.doctor(55).toJson();
    expect(json, containsPair('role', 'doctor'));
    expect(json, isNot(contains('clinicalTruth')));
    expect(json, isNot(contains('permissions')));
  });
}
