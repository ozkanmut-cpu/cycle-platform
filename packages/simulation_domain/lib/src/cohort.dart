import 'dart:convert';

import 'personas.dart';

const int cohortSchemaVersion = 1;
const int canonicalPatientCount = 100;
const int canonicalPartnerCount = 50;
const int canonicalDoctorCount = 5;

class PartnerPatientLink {
  const PartnerPatientLink({required this.partnerId, required this.patientId});
  final String partnerId;
  final String patientId;
  Map<String, Object?> toJson() =>
      {'partnerId': partnerId, 'patientId': patientId};
  factory PartnerPatientLink.fromJson(Map<String, Object?> json) =>
      PartnerPatientLink(
          partnerId: json['partnerId'] as String,
          patientId: json['patientId'] as String);
}

class DoctorPatientAssignment {
  const DoctorPatientAssignment(
      {required this.doctorId, required this.patientIds});
  final String doctorId;
  final List<String> patientIds;
  Map<String, Object?> toJson() =>
      {'doctorId': doctorId, 'patientIds': patientIds};
  factory DoctorPatientAssignment.fromJson(Map<String, Object?> json) =>
      DoctorPatientAssignment(
          doctorId: json['doctorId'] as String,
          patientIds: (json['patientIds'] as List).cast<String>());
}

class SimulationCohort {
  const SimulationCohort({
    required this.seed,
    required this.patients,
    required this.partners,
    required this.doctors,
    required this.partnerLinks,
    required this.doctorAssignments,
  });
  final int seed;
  final List<PatientPersona> patients;
  final List<PartnerPersona> partners;
  final List<DoctorPersona> doctors;
  final List<PartnerPatientLink> partnerLinks;
  final List<DoctorPatientAssignment> doctorAssignments;

  void validate() {
    if (patients.length != canonicalPatientCount ||
        partners.length != canonicalPartnerCount ||
        doctors.length != canonicalDoctorCount) {
      throw ArgumentError(
          'Canonical cohort must contain exactly 100 patients, 50 partners and 5 doctors');
    }
    final all = <SimulationPersona>[...patients, ...partners, ...doctors];
    final ids = all.map((p) => p.id).toSet();
    if (ids.length != all.length)
      throw ArgumentError('Cohort actor IDs must be globally unique');
    for (final persona in all) persona.validate();
    if (partnerLinks.length != partners.length)
      throw ArgumentError('Every partner requires one patient link');
    final patientIds = patients.map((p) => p.id).toSet();
    final partnerIds = partners.map((p) => p.id).toSet();
    if (partnerLinks.map((l) => l.partnerId).toSet().length !=
        partners.length) {
      throw ArgumentError(
          'Every partner must have exactly one relationship link');
    }
    for (final link in partnerLinks) {
      if (!partnerIds.contains(link.partnerId) ||
          !patientIds.contains(link.patientId)) {
        throw ArgumentError('Partner link contains a dangling actor ID');
      }
    }
    if (doctorAssignments.length != doctors.length)
      throw ArgumentError('Every doctor requires an assignment');
    final doctorIds = doctors.map((d) => d.id).toSet();
    final assigned = <String>{};
    for (final assignment in doctorAssignments) {
      if (!doctorIds.contains(assignment.doctorId))
        throw ArgumentError('Doctor assignment contains a dangling doctor ID');
      for (final patientId in assignment.patientIds) {
        if (!patientIds.contains(patientId))
          throw ArgumentError(
              'Doctor assignment contains a dangling patient ID');
        if (!assigned.add(patientId))
          throw ArgumentError('Patient assigned to multiple canonical doctors');
      }
    }
    if (assigned.length != patients.length)
      throw ArgumentError(
          'Every patient requires deterministic doctor coverage');
    _validateCoverage();
  }

  void _validateCoverage() {
    bool anyPatient(bool Function(PatientPersona) predicate) =>
        patients.any(predicate);
    if (!anyPatient((p) => p.core.healthLiteracy == LiteracyLevel.low) ||
        !anyPatient((p) => p.core.digitalLiteracy == LiteracyLevel.low) ||
        !anyPatient((p) => p.core.accessibilityNeeds.isNotEmpty) ||
        !anyPatient(
            (p) => p.core.privacySensitivity == PrivacySensitivity.high) ||
        !anyPatient((p) => p.core.wearableUse == WearableUse.heavy) ||
        !anyPatient((p) => p.core.wearableUse == WearableUse.none) ||
        !anyPatient(
            (p) => p.missingnessPattern == MissingnessPattern.conflicting) ||
        !anyPatient(
            (p) => p.missingnessPattern == MissingnessPattern.prolonged) ||
        !anyPatient((p) => p.symptomBurden >= 8)) {
      throw ArgumentError('Cohort is missing required high-risk coverage');
    }
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': cohortSchemaVersion,
        'seed': seed,
        'patients': patients.map((p) => p.toJson()).toList(),
        'partners': partners.map((p) => p.toJson()).toList(),
        'doctors': doctors.map((p) => p.toJson()).toList(),
        'partnerLinks': partnerLinks.map((l) => l.toJson()).toList(),
        'doctorAssignments': doctorAssignments.map((a) => a.toJson()).toList(),
        'coverage': coverageSummary(),
      };

  String toNormalizedJson() => jsonEncode(toJson());

  Map<String, Object?> coverageSummary() => {
        'patients': patients.length,
        'partners': partners.length,
        'doctors': doctors.length,
        'lowHealthLiteracy': patients
            .where((p) => p.core.healthLiteracy == LiteracyLevel.low)
            .length,
        'accessibilityNeeds':
            patients.where((p) => p.core.accessibilityNeeds.isNotEmpty).length,
        'highPrivacy': patients
            .where((p) => p.core.privacySensitivity == PrivacySensitivity.high)
            .length,
        'wearableHeavy': patients
            .where((p) => p.core.wearableUse == WearableUse.heavy)
            .length,
        'noWearable': patients
            .where((p) => p.core.wearableUse == WearableUse.none)
            .length,
        'conflictingData': patients
            .where(
                (p) => p.missingnessPattern == MissingnessPattern.conflicting)
            .length,
        'highSymptomBurden': patients.where((p) => p.symptomBurden >= 8).length,
      };

  factory SimulationCohort.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != cohortSchemaVersion) {
      throw FormatException(
          'Unsupported cohort schemaVersion: ${json['schemaVersion']}');
    }
    List<T> personas<T extends SimulationPersona>(String field) => (json[field]
            as List)
        .map((value) =>
            SimulationPersona.fromJson((value as Map).cast<String, Object?>()))
        .cast<T>()
        .toList();
    final cohort = SimulationCohort(
      seed: json['seed'] as int,
      patients: personas<PatientPersona>('patients'),
      partners: personas<PartnerPersona>('partners'),
      doctors: personas<DoctorPersona>('doctors'),
      partnerLinks: (json['partnerLinks'] as List)
          .map((v) =>
              PartnerPatientLink.fromJson((v as Map).cast<String, Object?>()))
          .toList(),
      doctorAssignments: (json['doctorAssignments'] as List)
          .map((v) => DoctorPatientAssignment.fromJson(
              (v as Map).cast<String, Object?>()))
          .toList(),
    );
    cohort.validate();
    return cohort;
  }
}

class CohortGenerator {
  const CohortGenerator({this.personaGenerator = const PersonaGenerator()});
  final PersonaGenerator personaGenerator;

  SimulationCohort canonical(int seed) {
    final patients = List<PatientPersona>.generate(
        canonicalPatientCount, (i) => _patient(seed, i));
    final partners = List<PartnerPersona>.generate(canonicalPartnerCount,
        (i) => personaGenerator.partner(seed + 2000 + i));
    final doctors = List<DoctorPersona>.generate(
        canonicalDoctorCount, (i) => personaGenerator.doctor(seed + 3000 + i));
    final links = List<PartnerPatientLink>.generate(
        partners.length,
        (i) => PartnerPatientLink(
            partnerId: partners[i].id,
            patientId: patients[(i * 2) % patients.length].id));
    final assignments =
        List<DoctorPatientAssignment>.generate(doctors.length, (doctorIndex) {
      final patientIds = <String>[];
      for (var i = doctorIndex; i < patients.length; i += doctors.length) {
        patientIds.add(patients[i].id);
      }
      return DoctorPatientAssignment(
          doctorId: doctors[doctorIndex].id, patientIds: patientIds);
    });
    final cohort = SimulationCohort(
        seed: seed,
        patients: patients,
        partners: partners,
        doctors: doctors,
        partnerLinks: links,
        doctorAssignments: assignments);
    cohort.validate();
    return cohort;
  }

  PatientPersona _patient(int seed, int index) {
    final base = personaGenerator.patient(seed + 1000 + index);
    final wearable =
        index % 10 == 0 ? WearableUse.heavy : base.core.wearableUse;
    final core = PersonaCore(
      age: 18 + ((index * 7 + seed.abs()) % 73),
      healthLiteracy:
          index % 9 == 0 ? LiteracyLevel.low : base.core.healthLiteracy,
      digitalLiteracy:
          index % 11 == 0 ? LiteracyLevel.low : base.core.digitalLiteracy,
      accessibilityNeeds:
          index % 8 == 0 ? const ['largeText'] : base.core.accessibilityNeeds,
      privacySensitivity: index % 7 == 0
          ? PrivacySensitivity.high
          : base.core.privacySensitivity,
      dataDensity: wearable == WearableUse.heavy
          ? DataDensity.high
          : base.core.dataDensity,
      wearableUse: wearable,
      loggingBehaviour: wearable == WearableUse.heavy
          ? LoggingBehaviour.regular
          : base.core.loggingBehaviour,
      goals: base.core.goals,
      fears: base.core.fears,
      expectedMentalModel: base.core.expectedMentalModel,
    );
    final patient = PatientPersona(
      id: base.id,
      core: core,
      cycleLifeStage:
          CycleLifeStage.values[index % (CycleLifeStage.values.length - 1)],
      conditions: index % 6 == 0
          ? const ['complex-chronic-condition']
          : base.conditions,
      medications: index % 6 == 0
          ? const ['maintenance-medication', 'second-medication']
          : base.medications,
      symptomBurden: index % 10 == 0 ? 9 : base.symptomBurden,
      missingnessPattern: index % 13 == 0
          ? MissingnessPattern.conflicting
          : index % 17 == 0
              ? MissingnessPattern.prolonged
              : base.missingnessPattern,
      healthDataSources: wearable == WearableUse.heavy
          ? const ['wearable', 'manual']
          : base.healthDataSources,
    );
    patient.validate();
    return patient;
  }
}
