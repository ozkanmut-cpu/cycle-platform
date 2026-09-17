import 'dart:collection';
import 'dart:convert';

enum PatientJourneyFamily {
  privacyUnlockRecovery,
  privacyLifecycleRelock,
  todayComprehensionSurface,
  quickLogPersistence,
  timelineCalendarRetrieval,
  connectedHealthStates,
}

enum PatientJourneySeverity { none, s3, s4 }

class PatientJourneyScenario {
  PatientJourneyScenario({
    required this.id,
    required this.schemaVersion,
    required this.seed,
    required this.virtualNow,
    required this.fixtureId,
    required this.locale,
    required this.family,
    required List<String> actions,
    required List<String> assertions,
    List<String> expectedRecoveryAffordances = const <String>[],
    List<String> riskTags = const <String>[],
  }) : actions = List<String>.unmodifiable(actions),
       assertions = List<String>.unmodifiable(assertions),
       expectedRecoveryAffordances = List<String>.unmodifiable(
         expectedRecoveryAffordances,
       ),
       riskTags = List<String>.unmodifiable(riskTags) {
    _requireSchemaVersion(schemaVersion);
    _requireNonblank('id', id);
    _requireNonblank('fixtureId', fixtureId);
    _requireNonblank('locale', locale);
    _requireUtc('virtualNow', virtualNow);
    _requireUniqueNonblank('actions', actions, allowEmpty: false);
    _requireUniqueNonblank('assertions', assertions, allowEmpty: false);
    _requireUniqueNonblank(
      'expectedRecoveryAffordances',
      expectedRecoveryAffordances,
    );
    _requireUniqueNonblank('riskTags', riskTags);
  }

  final String id;
  final int schemaVersion;
  final int seed;
  final DateTime virtualNow;
  final String fixtureId;
  final String locale;
  final PatientJourneyFamily family;
  final List<String> actions;
  final List<String> assertions;
  final List<String> expectedRecoveryAffordances;
  final List<String> riskTags;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'schemaVersion': schemaVersion,
    'seed': seed,
    'virtualNow': virtualNow.toUtc().toIso8601String(),
    'fixtureId': fixtureId,
    'locale': locale,
    'family': family.name,
    'actions': actions,
    'assertions': _sortedStrings(assertions),
    'expectedRecoveryAffordances': _sortedStrings(
      expectedRecoveryAffordances,
    ),
    'riskTags': _sortedStrings(riskTags),
  };

  factory PatientJourneyScenario.fromJson(Map<String, Object?> json) =>
      PatientJourneyScenario(
        id: json['id']! as String,
        schemaVersion: json['schemaVersion']! as int,
        seed: json['seed']! as int,
        virtualNow: DateTime.parse(json['virtualNow']! as String),
        fixtureId: json['fixtureId']! as String,
        locale: json['locale']! as String,
        family: PatientJourneyFamily.values.byName(json['family']! as String),
        actions: _stringList(json['actions']),
        assertions: _stringList(json['assertions']),
        expectedRecoveryAffordances: _stringList(
          json['expectedRecoveryAffordances'],
        ),
        riskTags: _stringList(json['riskTags']),
      );
}

class PatientJourneyObservation {
  const PatientJourneyObservation({
    this.surfaceReached,
    this.satisfiedAssertions = const <String>[],
    this.repositoryEventDelta = 0,
    this.persistedEventType,
    this.auditActions = const <String>[],
    this.timelineExpected = false,
    this.timelineRetrieved = false,
    this.calendarExpected = false,
    this.calendarRetrieved = false,
    this.privacyCoverVisible = false,
    this.privacyCoverBypassed = false,
    this.sensitiveMarkerVisible = false,
    this.missingDisplayedAsZero = false,
    this.conflictDisplayedAsCertain = false,
    this.coreJourneyBlocked = false,
    this.recoveryAffordanceVisible,
    this.persistenceMatched,
    this.auditMatched,
    this.connectedHealthStateMatched,
    this.connectedHealthStates = const <String>[],
    this.connectedHealthCoverageSource,
    this.actionCount = 0,
    this.navigationCount = 0,
    this.recoveryCount = 0,
    this.malformedReasonCode,
    this.executionFailureCode,
  }) : assert(repositoryEventDelta >= 0),
       assert(actionCount >= 0),
       assert(navigationCount >= 0),
       assert(recoveryCount >= 0);

  final String? surfaceReached;
  final List<String> satisfiedAssertions;
  final int repositoryEventDelta;
  final String? persistedEventType;
  final List<String> auditActions;
  final bool timelineExpected;
  final bool timelineRetrieved;
  final bool calendarExpected;
  final bool calendarRetrieved;
  final bool privacyCoverVisible;
  final bool privacyCoverBypassed;
  final bool sensitiveMarkerVisible;
  final bool missingDisplayedAsZero;
  final bool conflictDisplayedAsCertain;
  final bool coreJourneyBlocked;
  final bool? recoveryAffordanceVisible;
  final bool? persistenceMatched;
  final bool? auditMatched;
  final bool? connectedHealthStateMatched;
  final List<String> connectedHealthStates;
  final String? connectedHealthCoverageSource;
  final int actionCount;
  final int navigationCount;
  final int recoveryCount;
  final String? malformedReasonCode;
  final String? executionFailureCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'surfaceReached': surfaceReached,
    'satisfiedAssertions': _sortedStrings(satisfiedAssertions),
    'repositoryEventDelta': repositoryEventDelta,
    'persistedEventType': persistedEventType,
    'auditActions': _sortedStrings(auditActions),
    'timelineExpected': timelineExpected,
    'timelineRetrieved': timelineRetrieved,
    'calendarExpected': calendarExpected,
    'calendarRetrieved': calendarRetrieved,
    'privacyCoverVisible': privacyCoverVisible,
    'privacyCoverBypassed': privacyCoverBypassed,
    'sensitiveMarkerVisible': sensitiveMarkerVisible,
    'missingDisplayedAsZero': missingDisplayedAsZero,
    'conflictDisplayedAsCertain': conflictDisplayedAsCertain,
    'coreJourneyBlocked': coreJourneyBlocked,
    'recoveryAffordanceVisible': recoveryAffordanceVisible,
    'persistenceMatched': persistenceMatched,
    'auditMatched': auditMatched,
    'connectedHealthStateMatched': connectedHealthStateMatched,
    'connectedHealthStates': _sortedStrings(connectedHealthStates),
    'connectedHealthCoverageSource': connectedHealthCoverageSource,
    'actionCount': actionCount,
    'navigationCount': navigationCount,
    'recoveryCount': recoveryCount,
    'malformedReasonCode': malformedReasonCode,
    'executionFailureCode': executionFailureCode,
  };

  factory PatientJourneyObservation.fromJson(Map<String, Object?> json) =>
      PatientJourneyObservation(
        surfaceReached: json['surfaceReached'] as String?,
        satisfiedAssertions: _stringList(json['satisfiedAssertions']),
        repositoryEventDelta: json['repositoryEventDelta']! as int,
        persistedEventType: json['persistedEventType'] as String?,
        auditActions: _stringList(json['auditActions']),
        timelineExpected: json['timelineExpected']! as bool,
        timelineRetrieved: json['timelineRetrieved']! as bool,
        calendarExpected: json['calendarExpected']! as bool,
        calendarRetrieved: json['calendarRetrieved']! as bool,
        privacyCoverVisible: json['privacyCoverVisible']! as bool,
        privacyCoverBypassed: json['privacyCoverBypassed']! as bool,
        sensitiveMarkerVisible: json['sensitiveMarkerVisible']! as bool,
        missingDisplayedAsZero: json['missingDisplayedAsZero']! as bool,
        conflictDisplayedAsCertain:
            json['conflictDisplayedAsCertain']! as bool,
        coreJourneyBlocked: json['coreJourneyBlocked']! as bool,
        recoveryAffordanceVisible:
            json['recoveryAffordanceVisible'] as bool?,
        persistenceMatched: json['persistenceMatched'] as bool?,
        auditMatched: json['auditMatched'] as bool?,
        connectedHealthStateMatched:
            json['connectedHealthStateMatched'] as bool?,
        connectedHealthStates: _stringList(json['connectedHealthStates']),
        connectedHealthCoverageSource:
            json['connectedHealthCoverageSource'] as String?,
        actionCount: json['actionCount']! as int,
        navigationCount: json['navigationCount']! as int,
        recoveryCount: json['recoveryCount']! as int,
        malformedReasonCode: json['malformedReasonCode'] as String?,
        executionFailureCode: json['executionFailureCode'] as String?,
      );
}

class PatientJourneyFinding {
  const PatientJourneyFinding({
    required this.category,
    required this.severity,
    required this.journeyId,
    required this.assertionId,
    required this.reasonCode,
    this.diagnostics = const <String, Object?>{},
  });

  final String category;
  final PatientJourneySeverity severity;
  final String journeyId;
  final String assertionId;
  final String reasonCode;
  final Map<String, Object?> diagnostics;

  Map<String, Object?> toJson() => <String, Object?>{
    'category': category,
    'severity': severity.name,
    'journeyId': journeyId,
    'assertionId': assertionId,
    'reasonCode': reasonCode,
    'diagnostics': _canonicalMap(diagnostics),
  };

  factory PatientJourneyFinding.fromJson(Map<String, Object?> json) =>
      PatientJourneyFinding(
        category: json['category']! as String,
        severity: PatientJourneySeverity.values.byName(
          json['severity']! as String,
        ),
        journeyId: json['journeyId']! as String,
        assertionId: json['assertionId']! as String,
        reasonCode: json['reasonCode']! as String,
        diagnostics: _objectMap(json['diagnostics']),
      );
}

class PatientJourneyResult {
  PatientJourneyResult({
    required this.scenario,
    required this.observation,
    required List<PatientJourneyFinding> findings,
    required Set<String> coverageLabels,
  }) : findings = List<PatientJourneyFinding>.unmodifiable(findings),
       coverageLabels = Set<String>.unmodifiable(coverageLabels);

  final PatientJourneyScenario scenario;
  final PatientJourneyObservation observation;
  final List<PatientJourneyFinding> findings;
  final Set<String> coverageLabels;

  bool get passed => findings.isEmpty;

  Map<String, Object?> toJson() {
    final sortedFindings = findings.toList()..sort(_compareFindings);
    return <String, Object?>{
      'scenario': scenario.toJson(),
      'observation': observation.toJson(),
      'findings': sortedFindings.map((finding) => finding.toJson()).toList(),
      'coverageLabels': _sortedStrings(coverageLabels),
      'passed': passed,
    };
  }

  factory PatientJourneyResult.fromJson(Map<String, Object?> json) =>
      PatientJourneyResult(
        scenario: PatientJourneyScenario.fromJson(
          _objectMap(json['scenario']),
        ),
        observation: PatientJourneyObservation.fromJson(
          _objectMap(json['observation']),
        ),
        findings: _objectList(json['findings'])
            .map(PatientJourneyFinding.fromJson)
            .toList(),
        coverageLabels: _stringList(json['coverageLabels']).toSet(),
      );
}

class PatientJourneyCoverage {
  const PatientJourneyCoverage({
    required this.configured,
    required this.evaluated,
    required this.passed,
    required this.failed,
    required this.malformed,
    required this.labels,
  }) : assert(configured >= 0),
       assert(evaluated >= 0),
       assert(passed >= 0),
       assert(failed >= 0),
       assert(malformed >= 0);

  static const Set<String> mandatoryLabels = <String>{
    'family:privacyUnlockRecovery',
    'family:privacyLifecycleRelock',
    'family:todayComprehensionSurface',
    'family:quickLogPersistence',
    'family:timelineCalendarRetrieval',
    'family:connectedHealthStates',
    'privacy:unlock-success',
    'privacy:auth-failure-recovery',
    'privacy:lifecycle-relock',
    'privacy:locked-negative-assertion',
    'today:known-cycle-day',
    'today:unknown-cycle-day',
    'quick-log:persistence',
    'quick-log:audit',
    'quick-log:timeline-visible',
    'history:timeline',
    'history:calendar',
    'connected-health:observed-home',
    'connected-health:missing-home',
    'connected-health:conflicting-home',
    'connected-health:provenance-home',
    'connected-health:stale-direct-widget',
    'fixture:P-001',
    'fixture:P-002',
    'fixture:P-005',
    'control:positive',
    'control:negative',
  };

  final int configured;
  final int evaluated;
  final int passed;
  final int failed;
  final int malformed;
  final Map<String, int> labels;

  Map<String, Object?> toJson() => <String, Object?>{
    'configured': configured,
    'evaluated': evaluated,
    'passed': passed,
    'failed': failed,
    'malformed': malformed,
    'labels': SplayTreeMap<String, int>.from(labels),
  };

  factory PatientJourneyCoverage.fromJson(Map<String, Object?> json) =>
      PatientJourneyCoverage(
        configured: json['configured']! as int,
        evaluated: json['evaluated']! as int,
        passed: json['passed']! as int,
        failed: json['failed']! as int,
        malformed: json['malformed']! as int,
        labels: _objectMap(
          json['labels'],
        ).map((key, value) => MapEntry<String, int>(key, value! as int)),
      );
}

class PatientJourneyReport {
  PatientJourneyReport({
    required this.schemaVersion,
    required this.seed,
    required this.virtualNow,
    required this.syntheticEvidenceOnly,
    required List<PatientJourneyResult> results,
    required List<PatientJourneyFinding> findings,
    required this.coverage,
    required this.actionCount,
    required this.navigationCount,
    required this.recoveryCount,
  }) : results = List<PatientJourneyResult>.unmodifiable(results),
       findings = List<PatientJourneyFinding>.unmodifiable(findings) {
    _requireSchemaVersion(schemaVersion);
    _requireUtc('virtualNow', virtualNow);
    _requireNonnegative('actionCount', actionCount);
    _requireNonnegative('navigationCount', navigationCount);
    _requireNonnegative('recoveryCount', recoveryCount);
    if (!syntheticEvidenceOnly) {
      throw ArgumentError.value(
        syntheticEvidenceOnly,
        'syntheticEvidenceOnly',
        'Patient Journey evidence must remain synthetic-only',
      );
    }
  }

  final int schemaVersion;
  final int seed;
  final DateTime virtualNow;
  final bool syntheticEvidenceOnly;
  final List<PatientJourneyResult> results;
  final List<PatientJourneyFinding> findings;
  final PatientJourneyCoverage coverage;
  final int actionCount;
  final int navigationCount;
  final int recoveryCount;

  bool get passed =>
      findings.isEmpty && results.every((result) => result.passed);

  String get failureSummary {
    final reasons = findings.map((finding) => finding.reasonCode).toList()
      ..sort();
    return reasons.join(',');
  }

  Map<String, Object?> toJson() {
    final sortedResults = results.toList()
      ..sort((a, b) => a.scenario.id.compareTo(b.scenario.id));
    final sortedFindings = findings.toList()..sort(_compareFindings);
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'seed': seed,
      'virtualNow': virtualNow.toUtc().toIso8601String(),
      'syntheticEvidenceOnly': syntheticEvidenceOnly,
      'results': sortedResults.map((result) => result.toJson()).toList(),
      'findings': sortedFindings.map((finding) => finding.toJson()).toList(),
      'coverage': coverage.toJson(),
      'actionCount': actionCount,
      'navigationCount': navigationCount,
      'recoveryCount': recoveryCount,
      'passed': passed,
      'failureSummary': failureSummary,
    };
  }

  factory PatientJourneyReport.fromJson(Map<String, Object?> json) =>
      PatientJourneyReport(
        schemaVersion: json['schemaVersion']! as int,
        seed: json['seed']! as int,
        virtualNow: DateTime.parse(json['virtualNow']! as String),
        syntheticEvidenceOnly: json['syntheticEvidenceOnly']! as bool,
        results: _objectList(
          json['results'],
        ).map(PatientJourneyResult.fromJson).toList(),
        findings: _objectList(
          json['findings'],
        ).map(PatientJourneyFinding.fromJson).toList(),
        coverage: PatientJourneyCoverage.fromJson(
          _objectMap(json['coverage']),
        ),
        actionCount: json['actionCount']! as int,
        navigationCount: json['navigationCount']! as int,
        recoveryCount: json['recoveryCount']! as int,
      );
}

class PatientJourneyDetector {
  PatientJourneyResult evaluate({
    required PatientJourneyScenario scenario,
    required PatientJourneyObservation observation,
    required Set<String> coverageLabels,
  }) {
    final findings = <PatientJourneyFinding>[];

    void add({
      required String category,
      required PatientJourneySeverity severity,
      required String assertionId,
      required String reasonCode,
    }) {
      findings.add(
        PatientJourneyFinding(
          category: category,
          severity: severity,
          journeyId: scenario.id,
          assertionId: assertionId,
          reasonCode: reasonCode,
        ),
      );
    }

    if (observation.privacyCoverBypassed) {
      add(
        category: 'privacy_cover_bypass',
        severity: PatientJourneySeverity.s4,
        assertionId: 'privacy-cover-active',
        reasonCode: 'privacy_cover_bypassed',
      );
    }
    if (observation.privacyCoverVisible &&
        observation.sensitiveMarkerVisible) {
      add(
        category: 'sensitive_content_exposed_while_locked',
        severity: PatientJourneySeverity.s4,
        assertionId: 'privacy-no-sensitive-content',
        reasonCode: 'locked_sensitive_marker_visible',
      );
    }
    if (observation.missingDisplayedAsZero) {
      add(
        category: 'missing_data_invented_as_zero',
        severity: PatientJourneySeverity.s4,
        assertionId: 'connected-health-missing-not-zero',
        reasonCode: 'missing_displayed_as_zero',
      );
    }
    if (observation.conflictDisplayedAsCertain) {
      add(
        category: 'conflict_collapsed_to_certainty',
        severity: PatientJourneySeverity.s4,
        assertionId: 'connected-health-conflict-visible',
        reasonCode: 'conflict_displayed_as_certain',
      );
    }
    if (observation.coreJourneyBlocked ||
        observation.executionFailureCode != null) {
      add(
        category: 'core_journey_blocked',
        severity: PatientJourneySeverity.s3,
        assertionId: 'core-journey-complete',
        reasonCode:
            observation.executionFailureCode ?? 'core_journey_blocked',
      );
    }
    if (observation.recoveryAffordanceVisible == false) {
      add(
        category: 'recovery_affordance_missing',
        severity: PatientJourneySeverity.s3,
        assertionId: 'recovery-affordance-visible',
        reasonCode: 'recovery_affordance_missing',
      );
    }
    if (observation.persistenceMatched == false) {
      add(
        category: 'persistence_mismatch',
        severity: PatientJourneySeverity.s3,
        assertionId: 'quick-log-persisted',
        reasonCode: 'persistence_mismatch',
      );
    }
    if (observation.auditMatched == false) {
      add(
        category: 'audit_mismatch',
        severity: PatientJourneySeverity.s3,
        assertionId: 'quick-log-audit-matched',
        reasonCode: 'audit_mismatch',
      );
    }
    if (observation.timelineExpected && !observation.timelineRetrieved) {
      add(
        category: 'timeline_retrieval_failure',
        severity: PatientJourneySeverity.s3,
        assertionId: 'timeline-event-visible',
        reasonCode: 'timeline_not_retrieved',
      );
    }
    if (observation.calendarExpected && !observation.calendarRetrieved) {
      add(
        category: 'calendar_retrieval_failure',
        severity: PatientJourneySeverity.s3,
        assertionId: 'calendar-event-visible',
        reasonCode: 'calendar_not_retrieved',
      );
    }
    if (observation.connectedHealthStateMatched == false) {
      add(
        category: 'connected_health_state_mismatch',
        severity: PatientJourneySeverity.s3,
        assertionId: 'connected-health-state-matched',
        reasonCode: 'connected_health_state_mismatch',
      );
    }
    if (observation.malformedReasonCode != null) {
      add(
        category: 'malformed_input',
        severity: PatientJourneySeverity.s3,
        assertionId: 'scenario-well-formed',
        reasonCode: observation.malformedReasonCode!,
      );
    }

    findings.sort(_compareFindings);
    return PatientJourneyResult(
      scenario: scenario,
      observation: observation,
      findings: findings,
      coverageLabels: coverageLabels,
    );
  }
}

class PatientJourneyReportBuilder {
  PatientJourneyReportBuilder({required this.seed, required this.virtualNow}) {
    _requireUtc('virtualNow', virtualNow);
  }

  final int seed;
  final DateTime virtualNow;

  PatientJourneyReport build({
    required Iterable<PatientJourneyResult> results,
  }) {
    final sortedResults = results.toList()
      ..sort((a, b) => a.scenario.id.compareTo(b.scenario.id));
    final ids = sortedResults.map((result) => result.scenario.id).toList();
    if (ids.toSet().length != ids.length) {
      throw ArgumentError.value(ids, 'results', 'duplicate journey ids');
    }

    final labelCounts = SplayTreeMap<String, int>();
    for (final result in sortedResults) {
      for (final label in result.coverageLabels) {
        labelCounts.update(label, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    final findings = sortedResults
        .expand((result) => result.findings)
        .toList();
    final missingLabels = PatientJourneyCoverage.mandatoryLabels
        .where((label) => !labelCounts.containsKey(label))
        .toList()
      ..sort();
    for (final label in missingLabels) {
      findings.add(
        PatientJourneyFinding(
          category: 'coverage_gap',
          severity: PatientJourneySeverity.s3,
          journeyId: 'coverage',
          assertionId: label,
          reasonCode: 'coverage_gap:$label',
        ),
      );
    }
    findings.sort(_compareFindings);

    final passed = sortedResults.where((result) => result.passed).length;
    final malformed = sortedResults
        .where(
          (result) => result.findings.any(
            (finding) => finding.category == 'malformed_input',
          ),
        )
        .length;

    return PatientJourneyReport(
      schemaVersion: 1,
      seed: seed,
      virtualNow: virtualNow,
      syntheticEvidenceOnly: true,
      results: sortedResults,
      findings: findings,
      coverage: PatientJourneyCoverage(
        configured: sortedResults.length,
        evaluated: sortedResults.length,
        passed: passed,
        failed: sortedResults.length - passed,
        malformed: malformed,
        labels: Map<String, int>.unmodifiable(labelCounts),
      ),
      actionCount: sortedResults.fold(
        0,
        (total, result) => total + result.observation.actionCount,
      ),
      navigationCount: sortedResults.fold(
        0,
        (total, result) => total + result.observation.navigationCount,
      ),
      recoveryCount: sortedResults.fold(
        0,
        (total, result) => total + result.observation.recoveryCount,
      ),
    );
  }
}

String canonicalPatientJourneyJson(PatientJourneyReport report) =>
    jsonEncode(report.toJson());

void _requireSchemaVersion(int schemaVersion) {
  if (schemaVersion != 1) {
    throw ArgumentError.value(
      schemaVersion,
      'schemaVersion',
      'only schema version 1 is supported',
    );
  }
}

void _requireUtc(String name, DateTime value) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'must be UTC');
  }
}

void _requireNonblank(String name, String value) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
}

void _requireNonnegative(String name, int value) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'must not be negative');
  }
}

void _requireUniqueNonblank(
  String name,
  Iterable<String> values, {
  bool allowEmpty = true,
}) {
  final entries = values.toList();
  if (!allowEmpty && entries.isEmpty) {
    throw ArgumentError.value(entries, name, 'must not be empty');
  }
  if (entries.any((value) => value.trim().isEmpty)) {
    throw ArgumentError.value(entries, name, 'must not contain blank ids');
  }
  if (entries.toSet().length != entries.length) {
    throw ArgumentError.value(entries, name, 'must not contain duplicates');
  }
}

int _compareFindings(PatientJourneyFinding a, PatientJourneyFinding b) {
  final journey = a.journeyId.compareTo(b.journeyId);
  if (journey != 0) return journey;
  final assertion = a.assertionId.compareTo(b.assertionId);
  if (assertion != 0) return assertion;
  final category = a.category.compareTo(b.category);
  if (category != 0) return category;
  return a.reasonCode.compareTo(b.reasonCode);
}

List<String> _sortedStrings(Iterable<String> values) => values.toList()..sort();

List<String> _stringList(Object? value) =>
    (value! as List<Object?>).cast<String>();

List<Map<String, Object?>> _objectList(Object? value) =>
    (value! as List<Object?>)
        .map(
          (entry) => Map<String, Object?>.from(
            entry! as Map<Object?, Object?>,
          ),
        )
        .toList();

Map<String, Object?> _objectMap(Object? value) =>
    Map<String, Object?>.from(value! as Map<Object?, Object?>);

Map<String, Object?> _canonicalMap(Map<String, Object?> value) {
  final sorted = SplayTreeMap<String, Object?>();
  for (final entry in value.entries) {
    sorted[entry.key] = _canonicalValue(entry.value);
  }
  return sorted;
}

Object? _canonicalValue(Object? value) {
  if (value is Map<Object?, Object?>) {
    return _canonicalMap(Map<String, Object?>.from(value));
  }
  if (value is List) {
    return value.map(_canonicalValue).toList();
  }
  return value;
}
