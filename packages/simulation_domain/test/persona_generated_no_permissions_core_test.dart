import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('shared core never carries permission fields', () {
    const generator = PersonaGenerator();
    for (final core in <PersonaCore>[generator.patient(1).core, generator.partner(2).core, generator.doctor(3).core]) {
      expect(core.toJson(), isNot(contains('permissions')));
      expect(core.toJson(), isNot(contains('sharingGrants')));
    }
  });
}
