import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  test('data density and wearable use are independent dimensions', () {
    const generator = PersonaGenerator();
    final core = generator.patient(19).core;
    expect(core.toJson(), contains('dataDensity'));
    expect(core.toJson(), contains('wearableUse'));
  });
}
