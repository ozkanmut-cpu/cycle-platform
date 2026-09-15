import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared core never carries clinical truth fields', () {
    const generator = PersonaGenerator();
    final core = generator.patient(59).core.toJson();
    expect(core, isNot(contains('clinicalTruth')));
    expect(core, isNot(contains('diagnosis')));
    expect(core, isNot(contains('certainty')));
  });
}
