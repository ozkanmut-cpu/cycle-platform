import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  const generator = PersonaGenerator();

  test('same seed produces stable patient persona', () {
    expect(jsonEncode(generator.patient(20260915).toJson()), jsonEncode(generator.patient(20260915).toJson()));
  });

  test('all persona roles round-trip without semantic loss', () {
    final personas = <SimulationPersona>[generator.patient(11), generator.partner(22), generator.doctor(33)];
    for (final persona in personas) {
      final decoded = SimulationPersona.fromJson((jsonDecode(jsonEncode(persona.toJson())) as Map).cast<String, Object?>());
      expect(jsonEncode(decoded.toJson()), jsonEncode(persona.toJson()));
    }
  });

  test('unsupported persona schema fails safely', () {
    final json = generator.patient(1).toJson()..['schemaVersion'] = 999;
    expect(() => SimulationPersona.fromJson(json), throwsFormatException);
  });

  test('patient wearable requires an explicit data source', () {
    final base = generator.patient(2);
    final invalid = PatientPersona(id: base.id, core: PersonaCore(age: base.core.age, healthLiteracy: base.core.healthLiteracy, digitalLiteracy: base.core.digitalLiteracy, accessibilityNeeds: base.core.accessibilityNeeds, privacySensitivity: base.core.privacySensitivity, dataDensity: base.core.dataDensity, wearableUse: WearableUse.regular, loggingBehaviour: base.core.loggingBehaviour, goals: base.core.goals, fears: base.core.fears, expectedMentalModel: base.core.expectedMentalModel), cycleLifeStage: base.cycleLifeStage, conditions: base.conditions, medications: base.medications, symptomBurden: base.symptomBurden, missingnessPattern: base.missingnessPattern, healthDataSources: const []);
    expect(invalid.validate, throwsArgumentError);
  });

  test('partner intimacy requires explicit intimacy category grant', () {
    final base = generator.partner(3);
    final invalid = PartnerPersona(id: base.id, core: base.core, relationshipType: base.relationshipType, sharingGrants: base.sharingGrants, relationshipCategoryGrants: const ['relationshipIntelligence'], playfulEnabled: true, intimacyEnabled: true, boundarySensitivity: base.boundarySensitivity);
    expect(invalid.validate, throwsArgumentError);
  });

  test('persona fixtures exercise high-risk usability dimensions', () {
    final patient = generator.patient(41);
    final partner = generator.partner(42);
    final doctor = generator.doctor(43);
    expect(patient.role, PersonaRole.patient);
    expect(partner.role, PersonaRole.partner);
    expect(doctor.role, PersonaRole.doctor);
    expect(patient.core.expectedMentalModel, contains('uncertainty'));
  });
}
