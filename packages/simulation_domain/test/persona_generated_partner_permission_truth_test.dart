import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('partner grants remain access context and do not create health facts', () {
    const generator = PersonaGenerator();
    final json = generator.partner(65).toJson();
    expect(json, contains('sharingGrants'));
    expect(json, isNot(contains('healthFacts')));
    expect(json, isNot(contains('clinicalTruth')));
  });
}
