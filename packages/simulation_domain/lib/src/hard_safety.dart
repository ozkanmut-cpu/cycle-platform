import 'dart:convert';

import 'package:cycle_clinical_copilot/cycle_clinical_copilot.dart';
import 'package:cycle_permissions/cycle_permissions.dart';
import 'package:cycle_sharing/cycle_sharing.dart';

import 'ground_truth_oracle.dart';
import 'health_world.dart';
import 'models.dart';

const int hardSafetySchemaVersion = 1;

enum HardSafetyInvariantId {
  uncertaintyMissingNotKnown('uncertainty.missing-not-known'),
  uncertaintyConflictNotCertain('uncertainty.conflict-not-certain'),
  uncertaintyEstimateNotKnown('uncertainty.estimate-not-known'),
  permissionRevocationBoundary('permission.revocation-boundary'),
  aiContextFirewall('ai.context-firewall'),
  aiEvidenceRequired('ai.evidence-required'),
  aiAutonomousClinicalAction('ai.autonomous-clinical-action'),
  clinicalDoctorReviewGate('clinical.doctor-review-gate'),
  relationshipClinicalTruthPreserved('relationship.clinical-truth-preserved');

  const HardSafetyInvariantId(this.wireName);
  final String wireName;

  static HardSafetyInvariantId fromWireName(String value) =>
      HardSafetyInvariantId.values.firstWhere(
        (item) => item.wireName == value,
        orElse: () =>
            throw ArgumentError('Unsupported hard-safety invariant: $value'),
      );
}

class HardSafetyCase {
  HardSafetyCase({
    required this.id,
    required this.invariantId,
    required this.observedAt,
    required this.seed,
    this.patientId,
    Map<String, Object?> input = const <String, Object?>{},
  }) : input = Map<String, Object?>.unmodifiable(input) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Hard-safety case id must not be blank');
    }
    if (!observedAt.isUtc) {
      throw ArgumentError('Hard-safety case timestamps must be UTC');
    }
    if (patientId != null && patientId!.trim().isEmpty) {
      throw ArgumentError('patientId must not be blank when present');
    }
  }

  final String id;
  final HardSafetyInvariantId invariantId;
  final String? patientId;
  final DateTime observedAt;
  final int seed;
  final Map<String, Object?> input;
}

class HardSafetyObservation {
  HardSafetyObservation(
      {Map<String, Object?> facts = const <String, Object?>{}})
      : facts = Map<String, Object?>.unmodifiable(facts);

  final Map<String, Object?> facts;
}

abstract class HardSafetyObserver {
  const HardSafetyObserver();
  HardSafetyObservation observe(HardSafetyCase safetyCase);
}

class ProductionHardSafetyObserver extends HardSafetyObserver {
  ProductionHardSafetyObserver({
    this.oracle = const GroundTruthOracle(),
    this.permissionEvaluator = const PermissionEvaluator(),
  });

  final GroundTruthOracle oracle;
  final PermissionEvaluator permissionEvaluator;

  @override
  HardSafetyObservation observe(HardSafetyCase safetyCase) {
    switch (safetyCase.invariantId) {
      case HardSafetyInvariantId.uncertaintyMissingNotKnown:
      case HardSafetyInvariantId.uncertaintyConflictNotCertain:
      case HardSafetyInvariantId.uncertaintyEstimateNotKnown:
        return _observeUncertainty(safetyCase);
      case HardSafetyInvariantId.permissionRevocationBoundary:
        return _observePermission(safetyCase);
      case HardSafetyInvariantId.aiContextFirewall:
        return _observeAiContext(safetyCase);
      case HardSafetyInvariantId.aiEvidenceRequired:
        return _observeAiEvidence(safetyCase);
      case HardSafetyInvariantId.aiAutonomousClinicalAction:
        return _observeAiAction(safetyCase);
      case HardSafetyInvariantId.clinicalDoctorReviewGate:
        return _observeDoctorReview(safetyCase);
      case HardSafetyInvariantId.relationshipClinicalTruthPreserved:
        return _observeClinicalTruth(safetyCase);
    }
  }

  HardSafetyObservation _observeUncertainty(HardSafetyCase safetyCase) {
    final patientId = safetyCase.patientId;
    if (patientId == null)
      throw ArgumentError('Uncertainty case requires patientId');
    final expected = _state(safetyCase.input['expectedState']);
    final actual = _state(safetyCase.input['actualState']);
    final claim = GroundTruthClaim(
      id: '${safetyCase.id}-truth',
      patientId: patientId,
      signal: HealthSignalKind.symptomSeverity,
      observedAt: safetyCase.observedAt,
      expectedState: expected,
      source: SyntheticSourceKind.manual,
      value: safetyCase.input['value'] as num?,
      conflictingValue: safetyCase.input['conflictingValue'] as num?,
    );
    final observation = OracleObservation(
      id: '${safetyCase.id}-observed',
      patientId: patientId,
      signal: HealthSignalKind.symptomSeverity,
      observedAt: safetyCase.observedAt,
      state: actual,
      source: SyntheticSourceKind.manual,
      value: safetyCase.input['actualValue'] as num?,
      conflictingValue: safetyCase.input['actualConflictingValue'] as num?,
    );
    final report = oracle.evaluate(
      seed: safetyCase.seed,
      truth: <GroundTruthClaim>[claim],
      observed: <OracleObservation>[observation],
    );
    return HardSafetyObservation(
      facts: <String, Object?>{
        'expectedState': expected.name,
        'actualState': actual.name,
        'oracleFindingCategory': report.findings.isEmpty
            ? null
            : report.findings.first.category.name,
      },
    );
  }

  HardSafetyObservation _observePermission(HardSafetyCase safetyCase) {
    final ownerId = _requiredString(safetyCase.input, 'ownerId');
    final recipientId = _requiredString(safetyCase.input, 'recipientId');
    final category = _requiredString(safetyCase.input, 'category');
    final createdAt = _requiredUtc(safetyCase.input, 'createdAt');
    final revokedAt = _requiredUtc(safetyCase.input, 'revokedAt');
    final requestAt = _requiredUtc(safetyCase.input, 'requestAt');
    final grant = PermissionGrant(
      id: '${safetyCase.id}-grant',
      ownerId: ownerId,
      recipientId: recipientId,
      recipientKind: RecipientKind.partner,
      actions: const <PermissionAction>{PermissionAction.view},
      scope: PermissionScope(categories: <String>{category}),
      createdAt: createdAt,
      revokedAt: revokedAt,
    );
    final decision = permissionEvaluator.evaluate(
      request: PermissionRequest(
        ownerId: ownerId,
        recipientId: recipientId,
        action: PermissionAction.view,
        category: category,
        at: requestAt,
      ),
      grants: <PermissionGrant>[grant],
    );
    return HardSafetyObservation(
      facts: <String, Object?>{
        'allowed': decision.allowed,
        'atOrAfterRevocation': !requestAt.isBefore(revokedAt),
        'decisionReason': decision.reason,
      },
    );
  }

  HardSafetyObservation _observeAiContext(HardSafetyCase safetyCase) {
    final context = _objectMap(safetyCase.input['context']);
    final allowedKeys = _stringSet(safetyCase.input['allowedKeys']);
    final blockedKeys = _stringSet(safetyCase.input['blockedKeys']);
    final mustReject = safetyCase.input['mustReject'] == true;
    var modelInvoked = false;
    final result = const AiOrchestrator().run(
      request: AiOrchestrationRequest(
        id: '${safetyCase.id}-request',
        patientId: safetyCase.patientId ?? 'unknown',
        purpose: 'hard-safety-context-check',
        context: context,
        availableEvidenceIds: const <String>{},
        requestedAt: safetyCase.observedAt,
      ),
      contextPolicy: AiContextPolicy(
        allowedKeys: allowedKeys,
        blockedKeys: blockedKeys,
      ),
      invokeModel: (_) {
        modelInvoked = true;
        return AiCandidateOutput(text: 'safe-control');
      },
    );
    return HardSafetyObservation(
      facts: <String, Object?>{
        'mustReject': mustReject,
        'validationFailed': result.disposition == AiValidationDisposition.fail,
        'modelInvoked': modelInvoked,
        'completedStage': result.audit.any(
          (entry) => entry.stage == AiOrchestrationStage.completed,
        ),
      },
    );
  }

  HardSafetyObservation _observeAiEvidence(HardSafetyCase safetyCase) {
    final evidenceIds = _stringList(safetyCase.input['evidenceIds']);
    final available = _stringSet(safetyCase.input['availableEvidenceIds']);
    final mustReject = safetyCase.input['mustReject'] == true;
    final validation = const AiEvidenceValidator().validate(
      output: AiCandidateOutput(
        text: 'hard-safety-evidence-check',
        claims: <AiClaim>[
          AiClaim(
            text: 'synthetic claim',
            evidenceIds: evidenceIds,
            evidenceRequired: true,
          ),
        ],
      ),
      availableEvidenceIds: available,
    );
    return HardSafetyObservation(
      facts: <String, Object?>{
        'mustReject': mustReject,
        'validationFailed':
            validation.disposition == AiValidationDisposition.fail,
        'reasons': validation.reasons.map((item) => item.name).toList()..sort(),
      },
    );
  }

  HardSafetyObservation _observeAiAction(HardSafetyCase safetyCase) {
    final actionName = _requiredString(safetyCase.input, 'action');
    final action = AiClinicalAction.values.firstWhere(
      (item) => item.name == actionName,
      orElse: () =>
          throw ArgumentError('Unsupported AI clinical action: $actionName'),
    );
    final mustReject = safetyCase.input['mustReject'] == true;
    final validation = const AiSafetyValidator().validate(
      AiCandidateOutput(
        text: 'hard-safety-action-check',
        proposedActions: <AiClinicalAction>[action],
      ),
    );
    return HardSafetyObservation(
      facts: <String, Object?>{
        'mustReject': mustReject,
        'validationFailed':
            validation.disposition == AiValidationDisposition.fail,
        'action': action.name,
        'reasons': validation.reasons.map((item) => item.name).toList()..sort(),
      },
    );
  }

  HardSafetyObservation _observeDoctorReview(HardSafetyCase safetyCase) {
    final proposalId = _requiredString(safetyCase.input, 'proposalId');
    final proposal = ProposedClinicalWrite(
      id: proposalId,
      patientId: safetyCase.patientId ?? 'unknown',
      actionType: 'synthetic-hard-safety-write',
      payload: const <String, Object?>{},
      evidenceIds: const <String>[],
    );
    DoctorReviewRecord? review;
    final reviewProposalId = safetyCase.input['reviewProposalId'];
    if (reviewProposalId != null) {
      if (reviewProposalId is! String || reviewProposalId.trim().isEmpty) {
        throw ArgumentError('reviewProposalId must be a non-blank string');
      }
      final decisionName = _requiredString(safetyCase.input, 'reviewDecision');
      final decision = ReviewDecision.values.firstWhere(
        (item) => item.name == decisionName,
        orElse: () =>
            throw ArgumentError('Unsupported review decision: $decisionName'),
      );
      review = DoctorReviewRecord(
        proposalId: reviewProposalId,
        reviewerId: 'D-001',
        decision: decision,
        reviewedAt: safetyCase.observedAt,
      );
    }
    final commitAllowed = const DoctorReviewGate().canCommit(proposal, review);
    return HardSafetyObservation(
      facts: <String, Object?>{
        'approvalExpected': safetyCase.input['approvalExpected'] == true,
        'commitAllowed': commitAllowed,
      },
    );
  }

  HardSafetyObservation _observeClinicalTruth(HardSafetyCase safetyCase) {
    final ownerId = _requiredString(safetyCase.input, 'ownerId');
    final recipientId = _requiredString(safetyCase.input, 'recipientId');
    final category = _requiredString(safetyCase.input, 'category');
    final truthText = _requiredString(safetyCase.input, 'truthText');
    final severityName = _requiredString(safetyCase.input, 'severity');
    final severity = ClinicalTruthSeverity.values.firstWhere(
      (item) => item.name == severityName,
      orElse: () => throw ArgumentError(
          'Unsupported clinical truth severity: $severityName'),
    );
    final composition = const PlayfulEngine().compose(
      ownerId: ownerId,
      recipientId: recipientId,
      category: category,
      at: safetyCase.observedAt,
      companionText: safetyCase.input['companionText'] as String? ?? '',
      preferences: PlayfulPresentationPreferences(
        enabled: safetyCase.input['preferencesEnabled'] != false,
      ),
      grants: const <RelationshipCategoryGrant>[],
      clinicalTruth: ClinicalTruthLayer(
        id: '${safetyCase.id}-truth',
        text: truthText,
        severity: severity,
        createdAt: safetyCase.observedAt,
      ),
      isSeriousClinical: severity != ClinicalTruthSeverity.informational,
    );
    final first = composition.layers.isEmpty ? null : composition.layers.first;
    return HardSafetyObservation(
      facts: <String, Object?>{
        'truthPresent': composition.layers.any(
          (layer) => layer.kind == PlayfulLayerKind.clinicalTruth,
        ),
        'firstLayerKind': first?.kind.name,
        'firstLayerText': first?.text,
        'firstLayerTone': first?.tone.name,
      },
    );
  }
}

class HardSafetySuite {
  const HardSafetySuite({required this.observer});

  final HardSafetyObserver observer;

  HardSafetyReport run({
    required int seed,
    required Iterable<HardSafetyCase> cases,
  }) {
    final results = <HardSafetyResult>[];
    for (final safetyCase in cases) {
      if (safetyCase.seed != seed) {
        results.add(_malformed(safetyCase, 'seed_mismatch'));
        continue;
      }
      try {
        final observation = observer.observe(safetyCase);
        results.add(_evaluate(safetyCase, observation));
      } catch (error) {
        results.add(_malformed(safetyCase, error.runtimeType.toString()));
      }
    }
    return HardSafetyReport(seed: seed, results: results);
  }

  HardSafetyResult _evaluate(
    HardSafetyCase safetyCase,
    HardSafetyObservation observation,
  ) {
    switch (safetyCase.invariantId) {
      case HardSafetyInvariantId.uncertaintyMissingNotKnown:
        return _oracleCollapseResult(
          safetyCase,
          observation,
          'missingCollapsedToKnown',
          'missing_collapsed',
        );
      case HardSafetyInvariantId.uncertaintyConflictNotCertain:
        return _oracleCollapseResult(
          safetyCase,
          observation,
          'conflictCollapsedToCertain',
          'conflict_collapsed',
        );
      case HardSafetyInvariantId.uncertaintyEstimateNotKnown:
        return _oracleCollapseResult(
          safetyCase,
          observation,
          'estimateCollapsedToKnown',
          'estimate_collapsed',
        );
      case HardSafetyInvariantId.permissionRevocationBoundary:
        final allowed = observation.facts['allowed'] == true;
        final atOrAfter = observation.facts['atOrAfterRevocation'] == true;
        return _result(
          safetyCase,
          passed: !(allowed && atOrAfter),
          reasonCode: allowed && atOrAfter ? 'revocation_breach' : 'ok',
          evidence: observation.facts,
        );
      case HardSafetyInvariantId.aiContextFirewall:
        final mustReject = observation.facts['mustReject'] == true;
        final contained = observation.facts['validationFailed'] == true &&
            observation.facts['modelInvoked'] != true &&
            observation.facts['completedStage'] != true;
        final breached = mustReject && !contained;
        return _result(
          safetyCase,
          passed: !breached,
          reasonCode: breached ? 'context_crossed_firewall' : 'ok',
          evidence: observation.facts,
        );
      case HardSafetyInvariantId.aiEvidenceRequired:
        final mustReject = observation.facts['mustReject'] == true;
        final breached =
            mustReject && observation.facts['validationFailed'] != true;
        return _result(
          safetyCase,
          passed: !breached,
          reasonCode: breached ? 'evidence_accepted' : 'ok',
          evidence: observation.facts,
        );
      case HardSafetyInvariantId.aiAutonomousClinicalAction:
        final mustReject = observation.facts['mustReject'] == true;
        final breached =
            mustReject && observation.facts['validationFailed'] != true;
        return _result(
          safetyCase,
          passed: !breached,
          reasonCode: breached ? 'autonomous_action_accepted' : 'ok',
          evidence: observation.facts,
        );
      case HardSafetyInvariantId.clinicalDoctorReviewGate:
        final approvalExpected = observation.facts['approvalExpected'] == true;
        final commitAllowed = observation.facts['commitAllowed'] == true;
        final breached = !approvalExpected && commitAllowed;
        return _result(
          safetyCase,
          passed: !breached,
          reasonCode: breached ? 'review_gate_bypassed' : 'ok',
          evidence: observation.facts,
        );
      case HardSafetyInvariantId.relationshipClinicalTruthPreserved:
        final expectedText = _requiredString(safetyCase.input, 'truthText');
        final corrupted = observation.facts['truthPresent'] != true ||
            observation.facts['firstLayerKind'] != 'clinicalTruth' ||
            observation.facts['firstLayerText'] != expectedText ||
            observation.facts['firstLayerTone'] != 'plain';
        return _result(
          safetyCase,
          passed: !corrupted,
          reasonCode: corrupted ? 'clinical_truth_corrupted' : 'ok',
          evidence: observation.facts,
        );
    }
  }

  HardSafetyResult _oracleCollapseResult(
    HardSafetyCase safetyCase,
    HardSafetyObservation observation,
    String category,
    String reasonCode,
  ) {
    final violated = observation.facts['oracleFindingCategory'] == category;
    return _result(
      safetyCase,
      passed: !violated,
      reasonCode: violated ? reasonCode : 'ok',
      evidence: observation.facts,
    );
  }

  HardSafetyResult _malformed(HardSafetyCase safetyCase, String errorType) =>
      _result(
        safetyCase,
        passed: false,
        reasonCode: 'malformed_case',
        evidence: <String, Object?>{'errorType': errorType},
      );

  HardSafetyResult _result(
    HardSafetyCase safetyCase, {
    required bool passed,
    required String reasonCode,
    required Map<String, Object?> evidence,
  }) =>
      HardSafetyResult(
        caseId: safetyCase.id,
        invariantId: safetyCase.invariantId,
        passed: passed,
        reasonCode: reasonCode,
        evaluatedAt: safetyCase.observedAt,
        evidence: evidence,
      );
}

SyntheticDataState _state(Object? value) {
  if (value is! String) throw ArgumentError('Synthetic state is required');
  return SyntheticDataState.values.firstWhere(
    (item) => item.name == value,
    orElse: () => throw ArgumentError('Unsupported synthetic state: $value'),
  );
}

Set<String> _stringSet(Object? value) => _stringList(value).toSet();

List<String> _stringList(Object? value) {
  if (value is! List) throw ArgumentError('Expected a string list');
  final output = <String>[];
  for (final item in value) {
    if (item is! String) throw ArgumentError('Expected a string list');
    output.add(item);
  }
  return output;
}

String _requiredString(Map<String, Object?> input, String key) {
  final value = input[key];
  if (value is! String || value.trim().isEmpty) {
    throw ArgumentError('$key is required');
  }
  return value;
}

DateTime _requiredUtc(Map<String, Object?> input, String key) {
  final value = _requiredString(input, key);
  final parsed = DateTime.parse(value);
  if (!parsed.isUtc) throw ArgumentError('$key must be UTC');
  return parsed;
}

class HardSafetyResult {
  HardSafetyResult({
    required this.caseId,
    required this.invariantId,
    required this.passed,
    required this.reasonCode,
    required this.evaluatedAt,
    Map<String, Object?> evidence = const <String, Object?>{},
  }) : evidence = Map<String, Object?>.unmodifiable(evidence) {
    if (caseId.trim().isEmpty || reasonCode.trim().isEmpty) {
      throw ArgumentError('Hard-safety result identifiers must not be blank');
    }
    if (!evaluatedAt.isUtc) {
      throw ArgumentError('Hard-safety result timestamps must be UTC');
    }
  }

  final String caseId;
  final HardSafetyInvariantId invariantId;
  final bool passed;
  final String reasonCode;
  final DateTime evaluatedAt;
  final Map<String, Object?> evidence;

  InvariantSeverity get severity => InvariantSeverity.s4;

  Map<String, Object?> toJson() => <String, Object?>{
        'caseId': caseId,
        'invariantId': invariantId.wireName,
        'passed': passed,
        'severity': severity.name,
        'reasonCode': reasonCode,
        'evaluatedAt': evaluatedAt.toIso8601String(),
        'evidence': _canonicalize(evidence),
      };

  factory HardSafetyResult.fromJson(Map<String, Object?> json) =>
      HardSafetyResult(
        caseId: json['caseId'] as String,
        invariantId:
            HardSafetyInvariantId.fromWireName(json['invariantId'] as String),
        passed: json['passed'] as bool,
        reasonCode: json['reasonCode'] as String,
        evaluatedAt: _parseUtc(json['evaluatedAt'] as String),
        evidence: _objectMap(json['evidence']),
      );
}

class HardSafetyCoverage {
  HardSafetyCoverage({required Iterable<HardSafetyResult> results})
      : evaluatedCases = results.length,
        passedCases = results.where((item) => item.passed).length,
        failedCases = results.where((item) => !item.passed).length,
        malformedInputFailures =
            results.where((item) => item.reasonCode == 'malformed_case').length,
        perInvariant = _coverageByInvariant(results);

  final int evaluatedCases;
  final int passedCases;
  final int failedCases;
  final int malformedInputFailures;
  final Map<String, Map<String, int>> perInvariant;

  Map<String, Object?> toJson() => <String, Object?>{
        'evaluatedCases': evaluatedCases,
        'passedCases': passedCases,
        'failedCases': failedCases,
        'malformedInputFailures': malformedInputFailures,
        'perInvariant': _canonicalize(perInvariant),
      };
}

class HardSafetyReport {
  HardSafetyReport(
      {required this.seed, required Iterable<HardSafetyResult> results})
      : results = List<HardSafetyResult>.unmodifiable(
          List<HardSafetyResult>.from(results)..sort(_compareResults),
        ) {
    coverage = HardSafetyCoverage(results: this.results);
  }

  final int seed;
  final List<HardSafetyResult> results;
  late final HardSafetyCoverage coverage;

  bool get passed => results.every((item) => item.passed);

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': hardSafetySchemaVersion,
        'seed': seed,
        'syntheticEvidenceOnly': true,
        'passed': passed,
        'coverage': coverage.toJson(),
        'results': results.map((item) => item.toJson()).toList(growable: false),
      };

  String toNormalizedJson() => jsonEncode(_canonicalize(toJson()));

  factory HardSafetyReport.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != hardSafetySchemaVersion) {
      throw ArgumentError('Unsupported hard-safety schema version');
    }
    final rawResults = json['results'];
    if (rawResults is! List) {
      throw ArgumentError('Hard-safety report results must be a list');
    }
    return HardSafetyReport(
      seed: json['seed'] as int,
      results: rawResults
          .map((item) => HardSafetyResult.fromJson(_objectMap(item)))
          .toList(growable: false),
    );
  }
}

HardSafetyReport runProductionHardSafetySmoke(int seed) {
  final at = DateTime.utc(2026, 9, 16, 9);
  final revokedAt = at.add(const Duration(hours: 1));
  final cases = <HardSafetyCase>[
    HardSafetyCase(
      id: 'smoke-uncertainty-missing',
      invariantId: HardSafetyInvariantId.uncertaintyMissingNotKnown,
      patientId: 'P-001',
      observedAt: at,
      seed: seed,
      input: const <String, Object?>{
        'expectedState': 'missing',
        'actualState': 'missing',
      },
    ),
    HardSafetyCase(
      id: 'smoke-uncertainty-conflict',
      invariantId: HardSafetyInvariantId.uncertaintyConflictNotCertain,
      patientId: 'P-001',
      observedAt: at,
      seed: seed,
      input: const <String, Object?>{
        'expectedState': 'conflicting',
        'actualState': 'conflicting',
        'value': 5,
        'conflictingValue': 7,
        'actualValue': 5,
        'actualConflictingValue': 7,
      },
    ),
    HardSafetyCase(
      id: 'smoke-uncertainty-estimate',
      invariantId: HardSafetyInvariantId.uncertaintyEstimateNotKnown,
      patientId: 'P-001',
      observedAt: at,
      seed: seed,
      input: const <String, Object?>{
        'expectedState': 'estimated',
        'actualState': 'estimated',
        'value': 5,
        'actualValue': 5,
      },
    ),
    HardSafetyCase(
      id: 'smoke-permission-revocation',
      invariantId: HardSafetyInvariantId.permissionRevocationBoundary,
      observedAt: revokedAt,
      seed: seed,
      input: <String, Object?>{
        'ownerId': 'owner',
        'recipientId': 'partner',
        'category': 'cycle',
        'createdAt': at.toIso8601String(),
        'revokedAt': revokedAt.toIso8601String(),
        'requestAt': revokedAt.toIso8601String(),
      },
    ),
    HardSafetyCase(
      id: 'smoke-ai-context',
      invariantId: HardSafetyInvariantId.aiContextFirewall,
      patientId: 'P-001',
      observedAt: at,
      seed: seed,
      input: const <String, Object?>{
        'context': <String, Object?>{
          'question': 'Summarize',
          'secretRecoveryKey': 'blocked',
        },
        'allowedKeys': <String>['question'],
        'blockedKeys': <String>['secretRecoveryKey'],
        'mustReject': true,
      },
    ),
    HardSafetyCase(
      id: 'smoke-ai-evidence',
      invariantId: HardSafetyInvariantId.aiEvidenceRequired,
      patientId: 'P-001',
      observedAt: at,
      seed: seed,
      input: const <String, Object?>{
        'evidenceIds': <String>[],
        'availableEvidenceIds': <String>[],
        'mustReject': true,
      },
    ),
    HardSafetyCase(
      id: 'smoke-ai-action',
      invariantId: HardSafetyInvariantId.aiAutonomousClinicalAction,
      patientId: 'P-001',
      observedAt: at,
      seed: seed,
      input: const <String, Object?>{
        'action': 'prescribe',
        'mustReject': true,
      },
    ),
    HardSafetyCase(
      id: 'smoke-doctor-review',
      invariantId: HardSafetyInvariantId.clinicalDoctorReviewGate,
      patientId: 'P-001',
      observedAt: at,
      seed: seed,
      input: const <String, Object?>{
        'proposalId': 'proposal-smoke',
        'approvalExpected': false,
      },
    ),
    HardSafetyCase(
      id: 'smoke-clinical-truth',
      invariantId: HardSafetyInvariantId.relationshipClinicalTruthPreserved,
      patientId: 'P-001',
      observedAt: at,
      seed: seed,
      input: const <String, Object?>{
        'ownerId': 'P-001',
        'recipientId': 'partner-1',
        'category': 'health',
        'truthText': 'Urgent synthetic clinical truth',
        'severity': 'urgent',
        'preferencesEnabled': false,
        'companionText': 'Playful companion',
      },
    ),
  ];
  return HardSafetySuite(observer: ProductionHardSafetyObserver()).run(
    seed: seed,
    cases: cases,
  );
}

int _compareResults(HardSafetyResult left, HardSafetyResult right) {
  final invariant =
      left.invariantId.wireName.compareTo(right.invariantId.wireName);
  if (invariant != 0) return invariant;
  final caseId = left.caseId.compareTo(right.caseId);
  if (caseId != 0) return caseId;
  return left.evaluatedAt.compareTo(right.evaluatedAt);
}

Map<String, Map<String, int>> _coverageByInvariant(
  Iterable<HardSafetyResult> results,
) {
  final output = <String, Map<String, int>>{};
  for (final id in HardSafetyInvariantId.values) {
    final matches = results.where((item) => item.invariantId == id).toList();
    if (matches.isEmpty) continue;
    output[id.wireName] = <String, int>{
      'evaluated': matches.length,
      'failed': matches.where((item) => !item.passed).length,
    };
  }
  return Map.unmodifiable(output);
}

DateTime _parseUtc(String value) {
  final parsed = DateTime.parse(value);
  if (!parsed.isUtc) {
    throw ArgumentError('Hard-safety timestamps must be UTC');
  }
  return parsed;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) throw ArgumentError('Expected an object');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
