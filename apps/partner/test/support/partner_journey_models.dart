import 'dart:collection';
import 'dart:convert';

enum PartnerJourneyFamily {
  pairingLifecycle,
  partnerHomeNavigation,
  permissionScopedVisibility,
  notificationPrivacy,
  revocationDisconnect,
  relationshipSafetySurface,
}

enum PartnerJourneySeverity { none, s3, s4 }

const Set<String> mandatoryPartnerJourneyCoverageLabels = <String>{
  'family:pairingLifecycle',
  'family:partnerHomeNavigation',
  'family:permissionScopedVisibility',
  'family:notificationPrivacy',
  'family:revocationDisconnect',
  'family:relationshipSafetySurface',
  'pairing:valid',
  'pairing:malformed',
  'pairing:expired',
  'pairing:unsupported-version',
  'pairing:scope-mismatch',
  'pairing:retry-recovery',
  'home:unpaired-negative',
  'home:now',
  'home:us',
  'home:surprise',
  'home:shared-health',
  'visibility:fully-shared',
  'visibility:abstract-shared',
  'visibility:engine-only-hidden',
  'visibility:private-hidden',
  'visibility:wrong-recipient-hidden',
  'notification:generic',
  'notification:category-only',
  'notification:detailed-unlocked',
  'notification:detailed-locked-redacted',
  'notification:no-notify-suppressed',
  'notification:content-capability-suppressed',
  'revocation:key-rotation',
  'revocation:notifications-stopped',
  'revocation:content-cleared',
  'revocation:unpaired',
  'safety:no-consent-inference',
  'safety:no-invented-fallback',
  'safety:read-only',
  'fixture:RP-001',
  'fixture:RP-002',
  'fixture:RP-005',
  'control:positive',
  'control:negative',
};

const Set<String> _canonicalPartnerJourneyFixtureIds = <String>{
  'RP-001',
  'RP-002',
  'RP-005',
};

const Map<PartnerJourneyFamily, Set<String>> _familyCoverageLabels =
    <PartnerJourneyFamily, Set<String>>{
  PartnerJourneyFamily.pairingLifecycle: <String>{
    'pairing:valid',
    'pairing:malformed',
    'pairing:expired',
    'pairing:unsupported-version',
    'pairing:scope-mismatch',
    'pairing:retry-recovery',
  },
  PartnerJourneyFamily.partnerHomeNavigation: <String>{
    'home:unpaired-negative',
    'home:now',
    'home:us',
    'home:surprise',
    'home:shared-health',
  },
  PartnerJourneyFamily.permissionScopedVisibility: <String>{
    'visibility:fully-shared',
    'visibility:abstract-shared',
    'visibility:engine-only-hidden',
    'visibility:private-hidden',
    'visibility:wrong-recipient-hidden',
  },
  PartnerJourneyFamily.notificationPrivacy: <String>{
    'notification:generic',
    'notification:category-only',
    'notification:detailed-unlocked',
    'notification:detailed-locked-redacted',
    'notification:no-notify-suppressed',
    'notification:content-capability-suppressed',
  },
  PartnerJourneyFamily.revocationDisconnect: <String>{
    'revocation:key-rotation',
    'revocation:notifications-stopped',
    'revocation:content-cleared',
    'revocation:unpaired',
  },
  PartnerJourneyFamily.relationshipSafetySurface: <String>{
    'safety:no-consent-inference',
    'safety:no-invented-fallback',
    'safety:read-only',
  },
};

class PartnerJourneyScenario {
  PartnerJourneyScenario({
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
  })  : actions = List<String>.unmodifiable(actions),
        assertions = List<String>.unmodifiable(assertions),
        expectedRecoveryAffordances = List<String>.unmodifiable(
          expectedRecoveryAffordances,
        ),
        riskTags = List<String>.unmodifiable(riskTags) {
    _requireSchemaVersion(schemaVersion);
    _requireNonblank('id', id);
    _requireNonblank('fixtureId', fixtureId);
    if (!_canonicalPartnerJourneyFixtureIds.contains(fixtureId)) {
      throw ArgumentError.value(
        fixtureId,
        'fixtureId',
        'must be a canonical synthetic fixture id',
      );
    }
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
  final PartnerJourneyFamily family;
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
        'expectedRecoveryAffordances':
            _sortedStrings(expectedRecoveryAffordances),
        'riskTags': _sortedStrings(riskTags),
      };

  factory PartnerJourneyScenario.fromJson(Map<String, Object?> json) =>
      PartnerJourneyScenario(
        id: json['id']! as String,
        schemaVersion: json['schemaVersion']! as int,
        seed: json['seed']! as int,
        virtualNow: DateTime.parse(json['virtualNow']! as String),
        fixtureId: json['fixtureId']! as String,
        locale: json['locale']! as String,
        family: PartnerJourneyFamily.values.byName(json['family']! as String),
        actions: _stringList(json['actions']),
        assertions: _stringList(json['assertions']),
        expectedRecoveryAffordances: _stringList(
          json['expectedRecoveryAffordances'],
        ),
        riskTags: _stringList(json['riskTags']),
      );
}

class PartnerJourneyObservation {
  PartnerJourneyObservation({
    this.surfaceReached,
    this.pairingOutcomeCode,
    this.retryAffordanceObserved,
    List<String> visibleAssertionIds = const <String>[],
    List<String> forbiddenMarkerAbsenceAssertionIds = const <String>[],
    List<String> cardSummaries = const <String>[],
    this.rawValueVisible = false,
    this.notificationPreviewClass,
    this.notificationRedacted,
    this.recipientKeyVersionBefore,
    this.recipientKeyVersionAfter,
    this.notificationStopped,
    this.pairedAfterAction,
    this.actionCount = 0,
    this.navigationCount = 0,
    this.recoveryCount = 0,
    this.driverFailureCode,
    this.malformedReasonCode,
    this.determinismMismatch = false,
    this.unpairedSensitiveContentExposed = false,
    this.lockedNotificationDetailExposed = false,
    this.revokedContentRetained = false,
    this.notificationSentWithoutPermission = false,
    this.permissionScopeWidened = false,
    this.pairingInvalidPayloadAccepted = false,
    this.pairingScopeMismatchAccepted = false,
    this.recipientKeyNotRotated = false,
    this.consentInferredFromSensitiveData = false,
    this.coreJourneyBlocked = false,
    this.recoveryAffordanceMissing = false,
    this.partnerTabUnreachable = false,
    this.productionUiMismatch = false,
    this.disconnectIncomplete = false,
    this.notificationPreviewMismatch = false,
  })  : visibleAssertionIds = List<String>.unmodifiable(visibleAssertionIds),
        forbiddenMarkerAbsenceAssertionIds = List<String>.unmodifiable(
          forbiddenMarkerAbsenceAssertionIds,
        ),
        cardSummaries = List<String>.unmodifiable(cardSummaries),
        assert(actionCount >= 0),
        assert(navigationCount >= 0),
        assert(recoveryCount >= 0);

  final String? surfaceReached;
  final String? pairingOutcomeCode;
  final bool? retryAffordanceObserved;
  final List<String> visibleAssertionIds;
  final List<String> forbiddenMarkerAbsenceAssertionIds;
  final List<String> cardSummaries;
  final bool rawValueVisible;
  final String? notificationPreviewClass;
  final bool? notificationRedacted;
  final int? recipientKeyVersionBefore;
  final int? recipientKeyVersionAfter;
  final bool? notificationStopped;
  final bool? pairedAfterAction;
  final int actionCount;
  final int navigationCount;
  final int recoveryCount;
  final String? driverFailureCode;
  final String? malformedReasonCode;
  final bool determinismMismatch;
  final bool unpairedSensitiveContentExposed;
  final bool lockedNotificationDetailExposed;
  final bool revokedContentRetained;
  final bool notificationSentWithoutPermission;
  final bool permissionScopeWidened;
  final bool pairingInvalidPayloadAccepted;
  final bool pairingScopeMismatchAccepted;
  final bool recipientKeyNotRotated;
  final bool consentInferredFromSensitiveData;
  final bool coreJourneyBlocked;
  final bool recoveryAffordanceMissing;
  final bool partnerTabUnreachable;
  final bool productionUiMismatch;
  final bool disconnectIncomplete;
  final bool notificationPreviewMismatch;

  Map<String, Object?> toJson() => <String, Object?>{
        'surfaceReached': surfaceReached,
        'pairingOutcomeCode': pairingOutcomeCode,
        'retryAffordanceObserved': retryAffordanceObserved,
        'visibleAssertionIds': _sortedStrings(visibleAssertionIds),
        'forbiddenMarkerAbsenceAssertionIds': _sortedStrings(
          forbiddenMarkerAbsenceAssertionIds,
        ),
        'cardSummaries': _sortedStrings(cardSummaries),
        'rawValueVisible': rawValueVisible,
        'notificationPreviewClass': notificationPreviewClass,
        'notificationRedacted': notificationRedacted,
        'recipientKeyVersionBefore': recipientKeyVersionBefore,
        'recipientKeyVersionAfter': recipientKeyVersionAfter,
        'notificationStopped': notificationStopped,
        'pairedAfterAction': pairedAfterAction,
        'actionCount': actionCount,
        'navigationCount': navigationCount,
        'recoveryCount': recoveryCount,
        'driverFailureCode': driverFailureCode,
        'malformedReasonCode': malformedReasonCode,
        'determinismMismatch': determinismMismatch,
        'unpairedSensitiveContentExposed': unpairedSensitiveContentExposed,
        'lockedNotificationDetailExposed': lockedNotificationDetailExposed,
        'revokedContentRetained': revokedContentRetained,
        'notificationSentWithoutPermission': notificationSentWithoutPermission,
        'permissionScopeWidened': permissionScopeWidened,
        'pairingInvalidPayloadAccepted': pairingInvalidPayloadAccepted,
        'pairingScopeMismatchAccepted': pairingScopeMismatchAccepted,
        'recipientKeyNotRotated': recipientKeyNotRotated,
        'consentInferredFromSensitiveData': consentInferredFromSensitiveData,
        'coreJourneyBlocked': coreJourneyBlocked,
        'recoveryAffordanceMissing': recoveryAffordanceMissing,
        'partnerTabUnreachable': partnerTabUnreachable,
        'productionUiMismatch': productionUiMismatch,
        'disconnectIncomplete': disconnectIncomplete,
        'notificationPreviewMismatch': notificationPreviewMismatch,
      };

  factory PartnerJourneyObservation.fromJson(Map<String, Object?> json) =>
      PartnerJourneyObservation(
        surfaceReached: json['surfaceReached'] as String?,
        pairingOutcomeCode: json['pairingOutcomeCode'] as String?,
        retryAffordanceObserved: json['retryAffordanceObserved'] as bool?,
        visibleAssertionIds: _stringList(json['visibleAssertionIds']),
        forbiddenMarkerAbsenceAssertionIds: _stringList(
          json['forbiddenMarkerAbsenceAssertionIds'],
        ),
        cardSummaries: _stringList(json['cardSummaries']),
        rawValueVisible: json['rawValueVisible']! as bool,
        notificationPreviewClass: json['notificationPreviewClass'] as String?,
        notificationRedacted: json['notificationRedacted'] as bool?,
        recipientKeyVersionBefore: json['recipientKeyVersionBefore'] as int?,
        recipientKeyVersionAfter: json['recipientKeyVersionAfter'] as int?,
        notificationStopped: json['notificationStopped'] as bool?,
        pairedAfterAction: json['pairedAfterAction'] as bool?,
        actionCount: json['actionCount']! as int,
        navigationCount: json['navigationCount']! as int,
        recoveryCount: json['recoveryCount']! as int,
        driverFailureCode: json['driverFailureCode'] as String?,
        malformedReasonCode: json['malformedReasonCode'] as String?,
        determinismMismatch: json['determinismMismatch']! as bool,
        unpairedSensitiveContentExposed:
            json['unpairedSensitiveContentExposed']! as bool,
        lockedNotificationDetailExposed:
            json['lockedNotificationDetailExposed']! as bool,
        revokedContentRetained: json['revokedContentRetained']! as bool,
        notificationSentWithoutPermission:
            json['notificationSentWithoutPermission']! as bool,
        permissionScopeWidened: json['permissionScopeWidened']! as bool,
        pairingInvalidPayloadAccepted:
            json['pairingInvalidPayloadAccepted']! as bool,
        pairingScopeMismatchAccepted:
            json['pairingScopeMismatchAccepted']! as bool,
        recipientKeyNotRotated: json['recipientKeyNotRotated']! as bool,
        consentInferredFromSensitiveData:
            json['consentInferredFromSensitiveData']! as bool,
        coreJourneyBlocked: json['coreJourneyBlocked']! as bool,
        recoveryAffordanceMissing: json['recoveryAffordanceMissing']! as bool,
        partnerTabUnreachable: json['partnerTabUnreachable']! as bool,
        productionUiMismatch: json['productionUiMismatch']! as bool,
        disconnectIncomplete: json['disconnectIncomplete']! as bool,
        notificationPreviewMismatch:
            json['notificationPreviewMismatch']! as bool,
      );
}

class PartnerJourneyFinding {
  PartnerJourneyFinding({
    required this.category,
    required this.severity,
    required this.journeyId,
    required this.assertionId,
    required this.reasonCode,
    Map<String, Object?> diagnostics = const <String, Object?>{},
  }) : diagnostics = _canonicalDiagnostics(diagnostics);

  final String category;
  final PartnerJourneySeverity severity;
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
        'diagnostics': diagnostics,
      };

  factory PartnerJourneyFinding.fromJson(Map<String, Object?> json) =>
      PartnerJourneyFinding(
        category: json['category']! as String,
        severity: PartnerJourneySeverity.values.byName(
          json['severity']! as String,
        ),
        journeyId: json['journeyId']! as String,
        assertionId: json['assertionId']! as String,
        reasonCode: json['reasonCode']! as String,
        diagnostics: _objectMap(json['diagnostics']),
      );
}

class PartnerJourneyResult {
  PartnerJourneyResult({
    required this.scenario,
    required this.observation,
    required List<PartnerJourneyFinding> findings,
    required Set<String> coverageLabels,
  })  : findings = List<PartnerJourneyFinding>.unmodifiable(findings),
        coverageLabels = Set<String>.unmodifiable(
          _coverageLabelsForScenario(scenario, coverageLabels),
        );

  final PartnerJourneyScenario scenario;
  final PartnerJourneyObservation observation;
  final List<PartnerJourneyFinding> findings;
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

  factory PartnerJourneyResult.fromJson(Map<String, Object?> json) =>
      PartnerJourneyResult(
        scenario: PartnerJourneyScenario.fromJson(_objectMap(json['scenario'])),
        observation: PartnerJourneyObservation.fromJson(
          _objectMap(json['observation']),
        ),
        findings: _objectList(
          json['findings'],
        ).map(PartnerJourneyFinding.fromJson).toList(),
        coverageLabels: _stringList(json['coverageLabels']).toSet(),
      );
}

class PartnerJourneyCoverage {
  PartnerJourneyCoverage({
    required this.configured,
    required this.evaluated,
    required this.passed,
    required this.failed,
    required this.malformed,
    required Map<String, int> labels,
  }) : labels = Map<String, int>.unmodifiable(
            SplayTreeMap<String, int>.from(labels)) {
    _requireNonnegative('configured', configured);
    _requireNonnegative('evaluated', evaluated);
    _requireNonnegative('passed', passed);
    _requireNonnegative('failed', failed);
    _requireNonnegative('malformed', malformed);
  }

  final int configured;
  final int evaluated;
  final int passed;
  final int failed;
  final int malformed;
  final Map<String, int> labels;

  List<String> get missingLabels => mandatoryPartnerJourneyCoverageLabels
      .where((label) => !labels.containsKey(label))
      .toList()
    ..sort();

  Map<String, Object?> toJson() => <String, Object?>{
        'configured': configured,
        'evaluated': evaluated,
        'passed': passed,
        'failed': failed,
        'malformed': malformed,
        'labels': SplayTreeMap<String, int>.from(labels),
        'missingLabels': missingLabels,
      };

  factory PartnerJourneyCoverage.fromJson(Map<String, Object?> json) =>
      PartnerJourneyCoverage(
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

class PartnerJourneyReport {
  PartnerJourneyReport({
    required this.schemaVersion,
    required this.seed,
    required this.virtualNow,
    required this.syntheticEvidenceOnly,
    required List<PartnerJourneyResult> results,
    required List<PartnerJourneyFinding> findings,
    required this.coverage,
    required this.actionCount,
    required this.navigationCount,
    required this.recoveryCount,
  })  : results = List<PartnerJourneyResult>.unmodifiable(results),
        findings = List<PartnerJourneyFinding>.unmodifiable(findings) {
    _requireSchemaVersion(schemaVersion);
    _requireUtc('virtualNow', virtualNow);
    _requireNonnegative('actionCount', actionCount);
    _requireNonnegative('navigationCount', navigationCount);
    _requireNonnegative('recoveryCount', recoveryCount);
    if (!syntheticEvidenceOnly) {
      throw ArgumentError.value(
        syntheticEvidenceOnly,
        'syntheticEvidenceOnly',
        'Partner Journey evidence must remain synthetic-only',
      );
    }
  }

  final int schemaVersion;
  final int seed;
  final DateTime virtualNow;
  final bool syntheticEvidenceOnly;
  final List<PartnerJourneyResult> results;
  final List<PartnerJourneyFinding> findings;
  final PartnerJourneyCoverage coverage;
  final int actionCount;
  final int navigationCount;
  final int recoveryCount;

  bool get passed =>
      findings.isEmpty &&
      coverage.missingLabels.isEmpty &&
      coverage.failed == 0 &&
      coverage.malformed == 0 &&
      coverage.configured == coverage.evaluated &&
      coverage.evaluated == coverage.passed;

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

  factory PartnerJourneyReport.fromJson(Map<String, Object?> json) =>
      PartnerJourneyReport(
        schemaVersion: json['schemaVersion']! as int,
        seed: json['seed']! as int,
        virtualNow: DateTime.parse(json['virtualNow']! as String),
        syntheticEvidenceOnly: json['syntheticEvidenceOnly']! as bool,
        results: _objectList(
          json['results'],
        ).map(PartnerJourneyResult.fromJson).toList(),
        findings: _objectList(
          json['findings'],
        ).map(PartnerJourneyFinding.fromJson).toList(),
        coverage: PartnerJourneyCoverage.fromJson(_objectMap(json['coverage'])),
        actionCount: json['actionCount']! as int,
        navigationCount: json['navigationCount']! as int,
        recoveryCount: json['recoveryCount']! as int,
      );
}

class PartnerJourneyDetector {
  PartnerJourneyResult evaluate({
    required PartnerJourneyScenario scenario,
    required PartnerJourneyObservation observation,
    required Set<String> coverageLabels,
  }) {
    final findings = <PartnerJourneyFinding>[];

    void add(
      String category,
      PartnerJourneySeverity severity,
      String assertionId,
      String reasonCode,
    ) {
      findings.add(
        PartnerJourneyFinding(
          category: category,
          severity: severity,
          journeyId: scenario.id,
          assertionId: assertionId,
          reasonCode: reasonCode,
        ),
      );
    }

    final observedAssertions = observation.visibleAssertionIds.toSet();
    for (final assertionId in scenario.assertions) {
      if (!observedAssertions.contains(assertionId)) {
        add(
          'assertion_missing',
          PartnerJourneySeverity.s3,
          assertionId,
          'assertion_missing:$assertionId',
        );
      }
    }

    final s4 = <({bool active, String category, String assertion})>[
      (
        active: observation.unpairedSensitiveContentExposed,
        category: 'unpaired_sensitive_content_exposed',
        assertion: 'unpaired-content-hidden',
      ),
      (
        active: observation.lockedNotificationDetailExposed,
        category: 'locked_notification_detail_exposed',
        assertion: 'locked-notification-redacted',
      ),
      (
        active: observation.revokedContentRetained,
        category: 'revoked_content_retained',
        assertion: 'revoked-content-cleared',
      ),
      (
        active: observation.notificationSentWithoutPermission,
        category: 'notification_sent_without_permission',
        assertion: 'notification-permission-required',
      ),
      (
        active: observation.permissionScopeWidened,
        category: 'permission_scope_widened',
        assertion: 'permission-scope-preserved',
      ),
      (
        active: observation.pairingInvalidPayloadAccepted,
        category: 'pairing_invalid_payload_accepted',
        assertion: 'invalid-pairing-rejected',
      ),
      (
        active: observation.pairingScopeMismatchAccepted,
        category: 'pairing_scope_mismatch_accepted',
        assertion: 'pairing-scope-matched',
      ),
      (
        active: observation.recipientKeyNotRotated,
        category: 'recipient_key_not_rotated',
        assertion: 'recipient-key-rotated',
      ),
      (
        active: observation.consentInferredFromSensitiveData,
        category: 'consent_inferred_from_sensitive_data',
        assertion: 'consent-not-inferred',
      ),
    ];
    var hasS4 = false;
    for (final finding in s4.where((finding) => finding.active)) {
      add(
        finding.category,
        PartnerJourneySeverity.s4,
        finding.assertion,
        finding.category,
      );
      hasS4 = true;
    }

    final s3 = <({bool active, String category, String assertion})>[
      (
        active: observation.coreJourneyBlocked ||
            observation.driverFailureCode != null,
        category: 'core_journey_blocked',
        assertion: 'core-journey-complete',
      ),
      (
        active: observation.recoveryAffordanceMissing,
        category: 'recovery_affordance_missing',
        assertion: 'recovery-affordance-visible',
      ),
      (
        active: observation.partnerTabUnreachable,
        category: 'partner_tab_unreachable',
        assertion: 'partner-tab-reachable',
      ),
      (
        active: observation.productionUiMismatch,
        category: 'production_ui_mismatch',
        assertion: 'production-ui-matched',
      ),
      (
        active: observation.disconnectIncomplete && !hasS4,
        category: 'disconnect_incomplete',
        assertion: 'disconnect-complete',
      ),
      (
        active: observation.notificationPreviewMismatch && !hasS4,
        category: 'notification_preview_mismatch',
        assertion: 'notification-preview-matched',
      ),
    ];
    for (final finding in s3.where((finding) => finding.active)) {
      add(
        finding.category,
        PartnerJourneySeverity.s3,
        finding.assertion,
        finding.category == 'core_journey_blocked'
            ? observation.driverFailureCode ?? finding.category
            : finding.category,
      );
    }
    if (observation.malformedReasonCode != null) {
      add(
        'malformed_input',
        PartnerJourneySeverity.s3,
        'scenario-well-formed',
        observation.malformedReasonCode!,
      );
    }
    if (observation.determinismMismatch) {
      add(
        'determinism_mismatch',
        PartnerJourneySeverity.s3,
        'canonical-replay-byte-equality',
        'determinism_mismatch',
      );
    }
    findings.sort(_compareFindings);
    return PartnerJourneyResult(
      scenario: scenario,
      observation: observation,
      findings: findings,
      coverageLabels: coverageLabels,
    );
  }
}

class PartnerJourneyReportBuilder {
  PartnerJourneyReportBuilder({required this.seed, required this.virtualNow}) {
    _requireUtc('virtualNow', virtualNow);
  }

  final int seed;
  final DateTime virtualNow;

  PartnerJourneyReport build(Iterable<PartnerJourneyResult> results) {
    final sortedResults = results.toList()
      ..sort((a, b) => a.scenario.id.compareTo(b.scenario.id));
    final ids = sortedResults.map((result) => result.scenario.id).toList();
    if (ids.toSet().length != ids.length) {
      throw ArgumentError.value(ids, 'results', 'duplicate journey ids');
    }
    final labels = SplayTreeMap<String, int>();
    for (final result in sortedResults) {
      for (final label in result.coverageLabels) {
        labels.update(label, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final findings = sortedResults.expand((result) => result.findings).toList();
    final missing = mandatoryPartnerJourneyCoverageLabels
        .where((label) => !labels.containsKey(label))
        .toList()
      ..sort();
    for (final label in missing) {
      findings.add(
        PartnerJourneyFinding(
          category: 'coverage_gap',
          severity: PartnerJourneySeverity.s3,
          journeyId: 'coverage',
          assertionId: label,
          reasonCode: 'coverage_gap:$label',
        ),
      );
    }
    findings.sort(_compareFindings);
    final passedResults = sortedResults.where((result) => result.passed).length;
    final malformed = sortedResults
        .where(
          (result) => result.findings.any(
            (finding) => finding.category == 'malformed_input',
          ),
        )
        .length;
    return PartnerJourneyReport(
      schemaVersion: 1,
      seed: seed,
      virtualNow: virtualNow,
      syntheticEvidenceOnly: true,
      results: sortedResults,
      findings: findings,
      coverage: PartnerJourneyCoverage(
        configured: sortedResults.length,
        evaluated: sortedResults.length,
        passed: passedResults,
        failed: sortedResults.length - passedResults,
        malformed: malformed,
        labels: labels,
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

String canonicalPartnerJourneyJson(PartnerJourneyReport report) =>
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
  if (!value.isUtc) throw ArgumentError.value(value, name, 'must be UTC');
}

void _requireNonblank(String name, String value) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
}

void _requireNonnegative(String name, int value) {
  if (value < 0) throw ArgumentError.value(value, name, 'must not be negative');
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

int _compareFindings(PartnerJourneyFinding a, PartnerJourneyFinding b) {
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
          (entry) => Map<String, Object?>.from(entry! as Map<Object?, Object?>),
        )
        .toList();

Map<String, Object?> _objectMap(Object? value) =>
    Map<String, Object?>.from(value! as Map<Object?, Object?>);

Set<String> _coverageLabelsForScenario(
  PartnerJourneyScenario scenario,
  Set<String> labels,
) {
  final derived = <String>{
    'family:${scenario.family.name}',
    'fixture:${scenario.fixtureId}',
  };
  final allowed = <String>{
    ...derived,
    ..._familyCoverageLabels[scenario.family]!,
    'control:positive',
    'control:negative',
  };
  for (final label in labels) {
    if (!mandatoryPartnerJourneyCoverageLabels.contains(label) ||
        !allowed.contains(label)) {
      throw ArgumentError.value(
        label,
        'coverageLabels',
        'must be a mandatory label for the executed scenario family',
      );
    }
  }
  return <String>{...derived, ...labels};
}

Map<String, Object?> _canonicalDiagnostics(Map<String, Object?> value) {
  final sorted = SplayTreeMap<String, Object?>();
  for (final entry in value.entries) {
    sorted[_stableDiagnosticToken(entry.key)] = _canonicalDiagnosticValue(
      entry.value,
    );
  }
  return Map<String, Object?>.unmodifiable(sorted);
}

Object? _canonicalDiagnosticValue(Object? value) {
  if (value == null || value is bool || value is int) return value;
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'diagnostics', 'must be JSON-safe');
    }
    return value;
  }
  if (value is String) return _stableDiagnosticToken(value);
  if (value is Map<Object?, Object?>) {
    final map = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError.value(
            entry.key, 'diagnostics', 'keys must be strings');
      }
      map[_stableDiagnosticToken(entry.key as String)] =
          _canonicalDiagnosticValue(entry.value);
    }
    return Map<String, Object?>.unmodifiable(map);
  }
  if (value is List<Object?>) {
    final values = value.map(_canonicalDiagnosticValue).toList()
      ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    return List<Object?>.unmodifiable(values);
  }
  throw ArgumentError.value(
      value, 'diagnostics', 'must contain stable JSON values');
}

String _stableDiagnosticToken(String value) {
  if (!RegExp(r'^[a-z][a-z0-9_:-]*$').hasMatch(value)) {
    throw ArgumentError.value(value, 'diagnostics', 'must be a stable token');
  }
  return value;
}
