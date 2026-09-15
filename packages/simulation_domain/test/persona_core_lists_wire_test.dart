import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared core list wire values remain JSON arrays', () {
    const generator = PersonaGenerator();
    final json = generator.patient(96).core.toJson();
    expect(json['accessibilityNeeds'], isA<List<String>>());
    expect(json['goals'], isA<List<String>>());
    expect(json['fears'], isA<List<String>>());
  });
}
