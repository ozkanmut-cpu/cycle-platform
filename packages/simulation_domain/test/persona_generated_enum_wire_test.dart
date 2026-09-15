import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persona enum wire values serialize as names', () {
    const generator = PersonaGenerator();
    expect(generator.patient(90).toJson()['cycleLifeStage'], isA<String>());
    expect(generator.partner(91).toJson()['relationshipType'], isA<String>());
    expect(generator.doctor(92).toJson()['reviewStyle'], isA<String>());
  });
}
