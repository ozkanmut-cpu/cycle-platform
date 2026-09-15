import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('decoded wearable patient without source is rejected', () {
    const generator = PersonaGenerator();
    final json = generator.patient(38).toJson();
    final core = (json['core'] as Map<String, Object?>)..['wearableUse'] = WearableUse.regular.name;
    json['core'] = core;
    json['healthDataSources'] = <String>[];
    expect(() => SimulationPersona.fromJson(json), throwsArgumentError);
  });
}
