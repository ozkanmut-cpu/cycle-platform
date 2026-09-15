import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared core does not encode role-specific health sources', () {
    const generator = PersonaGenerator();
    final core = generator.patient(13).core.toJson();
    expect(core, isNot(contains('healthDataSources')));
    expect(core, isNot(contains('conditions')));
    expect(core, isNot(contains('relationshipCategoryGrants')));
  });
}
