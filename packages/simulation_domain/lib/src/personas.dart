import 'random.dart';

const int personaSchemaVersion = 1;

enum PersonaRole { patient, partner, doctor }
enum LiteracyLevel { low, medium, high }
enum PrivacySensitivity { low, medium, high }
enum DataDensity { none, low, medium, high }
enum WearableUse { none, occasional, regular, heavy }
enum LoggingBehaviour { sparse, irregular, regular, intensive }
enum CycleLifeStage { menstruating, fertilityPlanning, pregnant, postpartum, perimenopause, menopause, notApplicable }
enum MissingnessPattern { none, sporadic, clustered, prolonged, conflicting }
enum RelationshipType { dating, committed, cohabiting, married, separated, other }
enum BoundarySensitivity { low, medium, high }
enum SpecialtyProfile { primaryCare, gynecology, fertility, internalMedicine, complexCare }
enum CaseloadPressure { low, medium, high }
enum RiskTolerance { conservative, balanced, permissive }
enum ReviewStyle { summaryFirst, evidenceFirst, problemOriented, longitudinal }

T _enumByName<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is! String) throw FormatException('$field must be a string');
  return values.firstWhere(
    (item) => item.name == value,
    orElse: () => throw FormatException('Unsupported $field: $value'),
  );
}

List<String> _strings(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be a list');
  if (value.any((item) => item is! String)) {
    throw FormatException('$field must contain strings only');
  }
  return value.cast<String>();
}

class PersonaCore {
  const PersonaCore({
    required this.age,
    required this.healthLiteracy,
    required this.digitalLiteracy,
    required this.accessibilityNeeds,
    required this.privacySensitivity,
    required this.dataDensity,
    required this.wearableUse,
    required this.loggingBehaviour,
    required this.goals,
    required this.fears,
    required this.expectedMentalModel,
  });

  final int age;
  final LiteracyLevel healthLiteracy;
  final LiteracyLevel digitalLiteracy;
  final List<String> accessibilityNeeds;
  final PrivacySensitivity privacySensitivity;
  final DataDensity dataDensity;
  final WearableUse wearableUse;
  final LoggingBehaviour loggingBehaviour;
  final List<String> goals;
  final List<String> fears;
  final String expectedMentalModel;

  void validate() {
    if (age < 18 || age > 110) throw ArgumentError.value(age, 'age');
    if (expectedMentalModel.trim().isEmpty) {
      throw ArgumentError.value(expectedMentalModel, 'expectedMentalModel');
    }
    if (wearableUse == WearableUse.none && dataDensity == DataDensity.high &&
        loggingBehaviour == LoggingBehaviour.sparse) {
      throw ArgumentError('High data density requires a plausible data source');
    }
  }

  Map<String, Object?> toJson() => {
        'age': age,
        'healthLiteracy': healthLiteracy.name,
        'digitalLiteracy': digitalLiteracy.name,
        'accessibilityNeeds': accessibilityNeeds,
        'privacySensitivity': privacySensitivity.name,
        'dataDensity': dataDensity.name,
        'wearableUse': wearableUse.name,
        'loggingBehaviour': loggingBehaviour.name,
        'goals': goals,
        'fears': fears,
        'expectedMentalModel': expectedMentalModel,
      };

  factory PersonaCore.fromJson(Map<String, Object?> json) => PersonaCore(
        age: json['age'] as int,
        healthLiteracy: _enumByName(LiteracyLevel.values, json['healthLiteracy'], 'healthLiteracy'),
        digitalLiteracy: _enumByName(LiteracyLevel.values, json['digitalLiteracy'], 'digitalLiteracy'),
        accessibilityNeeds: _strings(json['accessibilityNeeds'], 'accessibilityNeeds'),
        privacySensitivity: _enumByName(PrivacySensitivity.values, json['privacySensitivity'], 'privacySensitivity'),
        dataDensity: _enumByName(DataDensity.values, json['dataDensity'], 'dataDensity'),
        wearableUse: _enumByName(WearableUse.values, json['wearableUse'], 'wearableUse'),
        loggingBehaviour: _enumByName(LoggingBehaviour.values, json['loggingBehaviour'], 'loggingBehaviour'),
        goals: _strings(json['goals'], 'goals'),
        fears: _strings(json['fears'], 'fears'),
        expectedMentalModel: json['expectedMentalModel'] as String,
      );
}

sealed class SimulationPersona {
  const SimulationPersona({required this.id, required this.core});
  final String id;
  final PersonaCore core;
  PersonaRole get role;
  void validate();
  Map<String, Object?> toJson();

  static SimulationPersona fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != personaSchemaVersion) {
      throw FormatException('Unsupported persona schemaVersion: ${json['schemaVersion']}');
    }
    final role = _enumByName(PersonaRole.values, json['role'], 'role');
    return switch (role) {
      PersonaRole.patient => PatientPersona.fromJson(json),
      PersonaRole.partner => PartnerPersona.fromJson(json),
      PersonaRole.doctor => DoctorPersona.fromJson(json),
    };
  }
}

class PatientPersona extends SimulationPersona {
  const PatientPersona({required super.id, required super.core, required this.cycleLifeStage, required this.conditions, required this.medications, required this.symptomBurden, required this.missingnessPattern, required this.healthDataSources});
  final CycleLifeStage cycleLifeStage;
  final List<String> conditions;
  final List<String> medications;
  final int symptomBurden;
  final MissingnessPattern missingnessPattern;
  final List<String> healthDataSources;
  @override PersonaRole get role => PersonaRole.patient;

  @override void validate() {
    core.validate();
    if (symptomBurden < 0 || symptomBurden > 10) throw ArgumentError.value(symptomBurden, 'symptomBurden');
    if (core.wearableUse != WearableUse.none && healthDataSources.isEmpty) {
      throw ArgumentError('Wearable use requires a health data source');
    }
  }

  @override Map<String, Object?> toJson() => {'schemaVersion': personaSchemaVersion, 'role': role.name, 'id': id, 'core': core.toJson(), 'cycleLifeStage': cycleLifeStage.name, 'conditions': conditions, 'medications': medications, 'symptomBurden': symptomBurden, 'missingnessPattern': missingnessPattern.name, 'healthDataSources': healthDataSources};
  factory PatientPersona.fromJson(Map<String, Object?> json) => PatientPersona(id: json['id'] as String, core: PersonaCore.fromJson((json['core'] as Map).cast<String, Object?>()), cycleLifeStage: _enumByName(CycleLifeStage.values, json['cycleLifeStage'], 'cycleLifeStage'), conditions: _strings(json['conditions'], 'conditions'), medications: _strings(json['medications'], 'medications'), symptomBurden: json['symptomBurden'] as int, missingnessPattern: _enumByName(MissingnessPattern.values, json['missingnessPattern'], 'missingnessPattern'), healthDataSources: _strings(json['healthDataSources'], 'healthDataSources'))..validate();
}

class PartnerPersona extends SimulationPersona {
  const PartnerPersona({required super.id, required super.core, required this.relationshipType, required this.sharingGrants, required this.relationshipCategoryGrants, required this.playfulEnabled, required this.intimacyEnabled, required this.boundarySensitivity});
  final RelationshipType relationshipType;
  final List<String> sharingGrants;
  final List<String> relationshipCategoryGrants;
  final bool playfulEnabled;
  final bool intimacyEnabled;
  final BoundarySensitivity boundarySensitivity;
  @override PersonaRole get role => PersonaRole.partner;

  @override void validate() {
    core.validate();
    if (intimacyEnabled && !relationshipCategoryGrants.contains('intimacy')) {
      throw ArgumentError('Intimacy preference requires an explicit intimacy grant');
    }
  }

  @override Map<String, Object?> toJson() => {'schemaVersion': personaSchemaVersion, 'role': role.name, 'id': id, 'core': core.toJson(), 'relationshipType': relationshipType.name, 'sharingGrants': sharingGrants, 'relationshipCategoryGrants': relationshipCategoryGrants, 'playfulEnabled': playfulEnabled, 'intimacyEnabled': intimacyEnabled, 'boundarySensitivity': boundarySensitivity.name};
  factory PartnerPersona.fromJson(Map<String, Object?> json) => PartnerPersona(id: json['id'] as String, core: PersonaCore.fromJson((json['core'] as Map).cast<String, Object?>()), relationshipType: _enumByName(RelationshipType.values, json['relationshipType'], 'relationshipType'), sharingGrants: _strings(json['sharingGrants'], 'sharingGrants'), relationshipCategoryGrants: _strings(json['relationshipCategoryGrants'], 'relationshipCategoryGrants'), playfulEnabled: json['playfulEnabled'] as bool, intimacyEnabled: json['intimacyEnabled'] as bool, boundarySensitivity: _enumByName(BoundarySensitivity.values, json['boundarySensitivity'], 'boundarySensitivity'))..validate();
}

class DoctorPersona extends SimulationPersona {
  const DoctorPersona({required super.id, required super.core, required this.specialtyProfile, required this.caseloadPressure, required this.riskTolerance, required this.reviewStyle});
  final SpecialtyProfile specialtyProfile;
  final CaseloadPressure caseloadPressure;
  final RiskTolerance riskTolerance;
  final ReviewStyle reviewStyle;
  @override PersonaRole get role => PersonaRole.doctor;
  @override void validate() => core.validate();
  @override Map<String, Object?> toJson() => {'schemaVersion': personaSchemaVersion, 'role': role.name, 'id': id, 'core': core.toJson(), 'specialtyProfile': specialtyProfile.name, 'caseloadPressure': caseloadPressure.name, 'riskTolerance': riskTolerance.name, 'reviewStyle': reviewStyle.name};
  factory DoctorPersona.fromJson(Map<String, Object?> json) => DoctorPersona(id: json['id'] as String, core: PersonaCore.fromJson((json['core'] as Map).cast<String, Object?>()), specialtyProfile: _enumByName(SpecialtyProfile.values, json['specialtyProfile'], 'specialtyProfile'), caseloadPressure: _enumByName(CaseloadPressure.values, json['caseloadPressure'], 'caseloadPressure'), riskTolerance: _enumByName(RiskTolerance.values, json['riskTolerance'], 'riskTolerance'), reviewStyle: _enumByName(ReviewStyle.values, json['reviewStyle'], 'reviewStyle'))..validate();
}

class PersonaGenerator {
  const PersonaGenerator();
  PatientPersona patient(int seed) {
    final r = DeterministicRandom(seed);
    final persona = PatientPersona(id: 'patient-$seed', core: _core(r, 18 + r.nextInt(73)), cycleLifeStage: CycleLifeStage.values[r.nextInt(CycleLifeStage.values.length - 1)], conditions: r.nextBool() ? ['chronic-condition'] : const [], medications: r.nextBool() ? ['maintenance-medication'] : const [], symptomBurden: r.nextInt(11), missingnessPattern: MissingnessPattern.values[r.nextInt(MissingnessPattern.values.length)], healthDataSources: const ['manual']);
    persona.validate();
    return persona;
  }
  PartnerPersona partner(int seed) {
    final r = DeterministicRandom(seed);
    final persona = PartnerPersona(id: 'partner-$seed', core: _core(r, 18 + r.nextInt(73)), relationshipType: RelationshipType.values[r.nextInt(RelationshipType.values.length)], sharingGrants: const ['relationship'], relationshipCategoryGrants: const ['relationshipIntelligence'], playfulEnabled: r.nextBool(), intimacyEnabled: false, boundarySensitivity: BoundarySensitivity.values[r.nextInt(BoundarySensitivity.values.length)]);
    persona.validate();
    return persona;
  }
  DoctorPersona doctor(int seed) {
    final r = DeterministicRandom(seed);
    final persona = DoctorPersona(id: 'doctor-$seed', core: _core(r, 28 + r.nextInt(53)), specialtyProfile: SpecialtyProfile.values[r.nextInt(SpecialtyProfile.values.length)], caseloadPressure: CaseloadPressure.values[r.nextInt(CaseloadPressure.values.length)], riskTolerance: RiskTolerance.values[r.nextInt(RiskTolerance.values.length)], reviewStyle: ReviewStyle.values[r.nextInt(ReviewStyle.values.length)]);
    persona.validate();
    return persona;
  }
  PersonaCore _core(DeterministicRandom r, int age) => PersonaCore(age: age, healthLiteracy: LiteracyLevel.values[r.nextInt(3)], digitalLiteracy: LiteracyLevel.values[r.nextInt(3)], accessibilityNeeds: r.nextInt(5) == 0 ? const ['largeText'] : const [], privacySensitivity: PrivacySensitivity.values[r.nextInt(3)], dataDensity: DataDensity.values[r.nextInt(DataDensity.values.length - 1)], wearableUse: WearableUse.none, loggingBehaviour: LoggingBehaviour.values[r.nextInt(LoggingBehaviour.values.length)], goals: const ['understand-health'], fears: const ['misinterpretation'], expectedMentalModel: 'Cycle shows what it knows and labels uncertainty.');
}
