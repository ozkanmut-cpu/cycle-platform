import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('all generated roles emit the same explicit schema version', () {
    const generator = PersonaGenerator();
    final versions = <Object?>{generator.patient(1).toJson()['schemaVersion'], generator.partner(2).toJson()['schemaVersion'], generator.doctor(3).toJson()['schemaVersion']};
    expect(versions, {personaSchemaVersion});
  });
}
