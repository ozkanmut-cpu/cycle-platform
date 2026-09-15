import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('doctor exposes specialty workload risk and review dimensions', () {
    const generator = PersonaGenerator();
    final json = generator.doctor(22).toJson();
    expect(json.keys, containsAll(<String>{'specialtyProfile', 'caseloadPressure', 'riskTolerance', 'reviewStyle'}));
  });
}
