import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generated partner preference fields remain booleans', () {
    const generator = PersonaGenerator();
    final json = generator.partner(88).toJson();
    expect(json['playfulEnabled'], isA<bool>());
    expect(json['intimacyEnabled'], isA<bool>());
  });
}
