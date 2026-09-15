import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('declared health data source does not imply observations', () {
    const generator = PersonaGenerator();
    final json = generator.patient(63).toJson();
    expect(json, contains('healthDataSources'));
    expect(json, isNot(contains('observations')));
  });
}
