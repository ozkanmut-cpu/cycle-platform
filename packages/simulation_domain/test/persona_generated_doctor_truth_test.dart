import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('doctor risk tolerance does not create clinical conclusions', () {
    const generator = PersonaGenerator();
    final json = generator.doctor(32).toJson();
    expect(json, contains('riskTolerance'));
    expect(json, isNot(contains('diagnosis')));
    expect(json, isNot(contains('recommendation')));
  });
}
