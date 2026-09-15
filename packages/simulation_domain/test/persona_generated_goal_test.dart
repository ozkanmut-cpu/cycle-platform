import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated shared goal does not imply a clinical outcome', () {
    const generator = PersonaGenerator();
    final goals = generator.patient(36).core.goals;
    expect(goals, const ['understand-health']);
    expect(goals, isNot(contains('get-diagnosis')));
  });
}
