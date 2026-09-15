import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('logging behaviour is explicit rather than inferred from literacy', () {
    const generator = PersonaGenerator();
    final core = generator.patient(21).core.toJson();
    expect(core, contains('loggingBehaviour'));
    expect(core, contains('healthLiteracy'));
  });
}
