import 'dart:convert';

import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:cycle_permissions/cycle_permissions.dart';
import 'package:cycle_sharing/cycle_sharing.dart';

import 'hard_safety.dart';
import 'models.dart';

const int privacyAttackSchemaVersion = 1;

enum PrivacyAttackFamily {
  identitySubstitution,
  actionEscalation,
  scopeSubstitution,
  temporalReplay,
  composedGrantConfusion,
  relationshipCapabilityEscalation,
  visibilityExfiltration,
  notificationLeakage,
  revocationAndKeyReplay,
  relayRecipientBinding,
}

enum PrivacyContainmentContract {
  allowAuthority,
  denyAuthority,
  allowProjection,
  denyProjection,
  allowRawExposure,
  noRawExposure,
  emitNotification,
  redactOrSuppressNotification,
  requireKeyRotation,
  rejectStaleKey,
  allowRelayDecrypt,
  rejectRelayDecrypt,
  rejectRelayIntegrityTamper,
}

class PrivacyAttackMutation {
  PrivacyAttackMutation({
    required this.id,
    required this.family,
    required this.sourceControlId,
    required Set<String> dimensions,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required this.paired,
  })  : dimensions = Set<String>.unmodifiable(dimensions),
        before = Map<String, Object?>.unmodifiable(before),
        after = Map<String, Object?>.unmodifiable(after) {
    _requireText(id, 'mutation.id');
    _requireText(sourceControlId, 'mutation.sourceControlId');
    if (dimensions.isEmpty) throw ArgumentError('mutation dimensions required');
    for (final dimension in dimensions) {
      _requireText(dimension, 'mutation.dimension');
    }
  }

  final String id;
  final PrivacyAttackFamily family;
  final String sourceControlId;
  final Set<String> dimensions;
  final Map<String, Object?> before;
  final Map<String, Object?> after;
  final bool paired;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'family': family.name,
        'sourceControlId': sourceControlId,
        'dimensions': dimensions.toList()..sort(),
        'before': _canonicalize(before),
        'after': _canonicalize(after),
        'paired': paired,
      };

  factory PrivacyAttackMutation.fromJson(Map<String, Object?> json) =>
      PrivacyAttackMutation(
        id: json['id'] as String,
        family: _enumByName(
          PrivacyAttackFamily.values,
          json['family'],
          'mutation.family',
        ),
        sourceControlId: json['sourceControlId'] as String,
        dimensions: _stringSet(json['dimensions']),
        before: _objectMap(json['before']),
        after: _objectMap(json['after']),
        paired: json['paired'] as bool,
      );
}

class PrivacyAttackScenario {
  PrivacyAttackScenario({
    required this.id,
    required this.sourceControlId,
    required this.schemaVersion,
    required this.seed,
    required this.at,
    required this.ownerId,
    required this.intendedRecipientId,
    required this.attemptedRecipientId,
    required this.family,
    required this.targetSurface,
    required this.mutation,
    required this.containmentContract,
    required Set<String> riskTags,
    Map<String, Object?> payload = const <String, Object?>{},
    this.safeControl = false,
    this.adversarial = false,
  })  : riskTags = Set<String>.unmodifiable(riskTags),
        payload = Map<String, Object?>.unmodifiable(payload) {
    if (schemaVersion != privacyAttackSchemaVersion) {
      throw ArgumentError('Unsupported privacy-attack schema version');
    }
    _requireText(id, 'id');
    _requireText(sourceControlId, 'sourceControlId');
    _requireText(ownerId, 'ownerId');
    _requireText(intendedRecipientId, 'intendedRecipientId');
    _requireText(attemptedRecipientId, 'attemptedRecipientId');
    _requireText(targetSurface, 'targetSurface');
    if (!at.isUtc) throw ArgumentError('at must be UTC');
    if (mutation.family != family) {
      throw ArgumentError('mutation family must match scenario family');
    }
    if (mutation.sourceControlId != sourceControlId) {
      throw ArgumentError('mutation sourceControlId must match scenario');
    }
    if (safeControl == adversarial) {
      throw ArgumentError(
          'scenario must be either safe control or adversarial');
    }
    for (final tag in riskTags) {
      _requireText(tag, 'riskTag');
    }
  }

  final String id;
  final String sourceControlId;
  final int schemaVersion;
  final int seed;
  final DateTime at;
  final String ownerId;
  final String intendedRecipientId;
  final String attemptedRecipientId;
  final PrivacyAttackFamily family;
  final String targetSurface;
  final PrivacyAttackMutation mutation;
  final PrivacyContainmentContract containmentContract;
  final Set<String> riskTags;
  final Map<String, Object?> payload;
  final bool safeControl;
  final bool adversarial;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'sourceControlId': sourceControlId,
        'schemaVersion': schemaVersion,
        'seed': seed,
        'at': at.toIso8601String(),
        'ownerId': ownerId,
        'intendedRecipientId': intendedRecipientId,
        'attemptedRecipientId': attemptedRecipientId,
        'family': family.name,
        'targetSurface': targetSurface,
        'mutation': mutation.toJson(),
        'containmentContract': containmentContract.name,
        'riskTags': riskTags.toList()..sort(),
        'payload': _canonicalize(payload),
        'safeControl': safeControl,
        'adversarial': adversarial,
      };

  factory PrivacyAttackScenario.fromJson(Map<String, Object?> json) =>
      PrivacyAttackScenario(
        id: json['id'] as String,
        sourceControlId: json['sourceControlId'] as String,
        schemaVersion: json['schemaVersion'] as int,
        seed: json['seed'] as int,
        at: _parseUtc(json['at'], 'at'),
        ownerId: json['ownerId'] as String,
        intendedRecipientId: json['intendedRecipientId'] as String,
        attemptedRecipientId: json['attemptedRecipientId'] as String,
        family: _enumByName(
          PrivacyAttackFamily.values,
          json['family'],
          'family',
        ),
        targetSurface: json['targetSurface'] as String,
        mutation: PrivacyAttackMutation.fromJson(_objectMap(json['mutation'])),
        containmentContract: _enumByName(
          PrivacyContainmentContract.values,
          json['containmentContract'],
          'containmentContract',
        ),
        riskTags: _stringSet(json['riskTags']),
        payload: _objectMap(json['payload']),
        safeControl: json['safeControl'] as bool? ?? false,
        adversarial: json['adversarial'] as bool? ?? false,
      );
}

class PrivacyAttackObservation {
  const PrivacyAttackObservation({
    this.allowed,
    this.projected,
    this.rawValueExposed,
    this.notificationEmitted,
    this.notificationRedacted,
    this.keyRotated,
    this.notificationsStopped,
    this.exportsInvalidated,
    this.staleKeyActive,
    this.relayDecryptAccepted,
    this.relayIntegrityAccepted,
    this.matchedGenericGrantId,
    this.matchedRelationshipGrantId,
    this.effectiveVisibility,
    this.reason,
  });

  final bool? allowed;
  final bool? projected;
  final bool? rawValueExposed;
  final bool? notificationEmitted;
  final bool? notificationRedacted;
  final bool? keyRotated;
  final bool? notificationsStopped;
  final bool? exportsInvalidated;
  final bool? staleKeyActive;
  final bool? relayDecryptAccepted;
  final bool? relayIntegrityAccepted;
  final String? matchedGenericGrantId;
  final String? matchedRelationshipGrantId;
  final String? effectiveVisibility;
  final String? reason;

  Map<String, Object?> toJson() => <String, Object?>{
        'allowed': allowed,
        'projected': projected,
        'rawValueExposed': rawValueExposed,
        'notificationEmitted': notificationEmitted,
        'notificationRedacted': notificationRedacted,
        'keyRotated': keyRotated,
        'notificationsStopped': notificationsStopped,
        'exportsInvalidated': exportsInvalidated,
        'staleKeyActive': staleKeyActive,
        'relayDecryptAccepted': relayDecryptAccepted,
        'relayIntegrityAccepted': relayIntegrityAccepted,
        'matchedGenericGrantId': matchedGenericGrantId,
        'matchedRelationshipGrantId': matchedRelationshipGrantId,
        'effectiveVisibility': effectiveVisibility,
        'reason': reason,
      };

  factory PrivacyAttackObservation.fromJson(Map<String, Object?> json) =>
      PrivacyAttackObservation(
        allowed: json['allowed'] as bool?,
        projected: json['projected'] as bool?,
        rawValueExposed: json['rawValueExposed'] as bool?,
        notificationEmitted: json['notificationEmitted'] as bool?,
        notificationRedacted: json['notificationRedacted'] as bool?,
        keyRotated: json['keyRotated'] as bool?,
        notificationsStopped: json['notificationsStopped'] as bool?,
        exportsInvalidated: json['exportsInvalidated'] as bool?,
        staleKeyActive: json['staleKeyActive'] as bool?,
        relayDecryptAccepted: json['relayDecryptAccepted'] as bool?,
        relayIntegrityAccepted: json['relayIntegrityAccepted'] as bool?,
        matchedGenericGrantId: json['matchedGenericGrantId'] as String?,
        matchedRelationshipGrantId:
            json['matchedRelationshipGrantId'] as String?,
        effectiveVisibility: json['effectiveVisibility'] as String?,
        reason: json['reason'] as String?,
      );
}

abstract class PrivacyAttackObserver {
  const PrivacyAttackObserver();

  Future<PrivacyAttackObservation> observe(PrivacyAttackScenario scenario);
}

class PrivacyAttackResult {
  PrivacyAttackResult({
    required this.scenarioId,
    required this.family,
    required this.passed,
    required this.findingCategory,
    required this.reasonCode,
    required this.evaluatedAt,
    required this.observation,
    this.malformedInput = false,
  }) {
    _requireText(scenarioId, 'scenarioId');
    _requireText(findingCategory, 'findingCategory');
    _requireText(reasonCode, 'reasonCode');
    if (!evaluatedAt.isUtc) throw ArgumentError('evaluatedAt must be UTC');
  }

  final String scenarioId;
  final PrivacyAttackFamily family;
  final bool passed;
  final String findingCategory;
  final String reasonCode;
  final DateTime evaluatedAt;
  final PrivacyAttackObservation observation;
  final bool malformedInput;
  InvariantSeverity get severity => InvariantSeverity.s4;

  Map<String, Object?> toJson() => <String, Object?>{
        'scenarioId': scenarioId,
        'family': family.name,
        'passed': passed,
        'findingCategory': findingCategory,
        'reasonCode': reasonCode,
        'severity': severity.name,
        'evaluatedAt': evaluatedAt.toIso8601String(),
        'observation': observation.toJson(),
        'malformedInput': malformedInput,
      };

  factory PrivacyAttackResult.fromJson(Map<String, Object?> json) =>
      PrivacyAttackResult(
        scenarioId: json['scenarioId'] as String,
        family: _enumByName(
          PrivacyAttackFamily.values,
          json['family'],
          'family',
        ),
        passed: json['passed'] as bool,
        findingCategory: json['findingCategory'] as String,
        reasonCode: json['reasonCode'] as String,
        evaluatedAt: _parseUtc(json['evaluatedAt'], 'evaluatedAt'),
        observation:
            PrivacyAttackObservation.fromJson(_objectMap(json['observation'])),
        malformedInput: json['malformedInput'] as bool? ?? false,
      );
}

class PrivacyAttackCoverage {
  const PrivacyAttackCoverage({
    this.configuredScenarios = 0,
    this.evaluatedScenarios = 0,
    this.passedScenarios = 0,
    this.failedScenarios = 0,
    this.malformedInputFailures = 0,
    this.safeControls = 0,
    this.adversarialScenarios = 0,
    this.families = const <String, int>{},
    this.riskTags = const <String, int>{},
    this.dimensions = const <String, int>{},
  });

  const PrivacyAttackCoverage.empty() : this();

  final int configuredScenarios;
  final int evaluatedScenarios;
  final int passedScenarios;
  final int failedScenarios;
  final int malformedInputFailures;
  final int safeControls;
  final int adversarialScenarios;
  final Map<String, int> families;
  final Map<String, int> riskTags;
  final Map<String, int> dimensions;

  factory PrivacyAttackCoverage.fromRun({
    required Iterable<PrivacyAttackScenario> scenarios,
    required Iterable<PrivacyAttackResult> results,
  }) {
    final scenarioList = scenarios.toList(growable: false);
    final resultList = results.toList(growable: false);
    final families = <String, int>{};
    final riskTags = <String, int>{};
    final dimensions = <String, int>{};
    for (final scenario in scenarioList) {
      families.update(
        scenario.family.name,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      for (final tag in scenario.riskTags) {
        riskTags.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
      for (final label in _scenarioCoverageLabels(scenario)) {
        dimensions.update(label, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return PrivacyAttackCoverage(
      configuredScenarios: scenarioList.length,
      evaluatedScenarios: resultList.length,
      passedScenarios: resultList.where((item) => item.passed).length,
      failedScenarios: resultList.where((item) => !item.passed).length,
      malformedInputFailures:
          resultList.where((item) => item.malformedInput).length,
      safeControls: scenarioList.where((item) => item.safeControl).length,
      adversarialScenarios:
          scenarioList.where((item) => item.adversarial).length,
      families: Map<String, int>.unmodifiable(families),
      riskTags: Map<String, int>.unmodifiable(riskTags),
      dimensions: Map<String, int>.unmodifiable(dimensions),
    );
  }
  Map<String, Object?> toJson() => <String, Object?>{
        'configuredScenarios': configuredScenarios,
        'evaluatedScenarios': evaluatedScenarios,
        'passedScenarios': passedScenarios,
        'failedScenarios': failedScenarios,
        'malformedInputFailures': malformedInputFailures,
        'safeControls': safeControls,
        'adversarialScenarios': adversarialScenarios,
        'families': _canonicalize(families),
        'riskTags': _canonicalize(riskTags),
        'dimensions': _canonicalize(dimensions),
      };

  factory PrivacyAttackCoverage.fromJson(Map<String, Object?> json) =>
      PrivacyAttackCoverage(
        configuredScenarios: json['configuredScenarios'] as int,
        evaluatedScenarios: json['evaluatedScenarios'] as int,
        passedScenarios: json['passedScenarios'] as int,
        failedScenarios: json['failedScenarios'] as int,
        malformedInputFailures: json['malformedInputFailures'] as int,
        safeControls: json['safeControls'] as int,
        adversarialScenarios: json['adversarialScenarios'] as int,
        families: _intMap(json['families']),
        riskTags: _intMap(json['riskTags']),
        dimensions: _intMap(json['dimensions']),
      );
}

class PrivacyAttackReport {
  PrivacyAttackReport({
    required this.seed,
    required Iterable<PrivacyAttackResult> results,
    required this.coverage,
  }) : results = List<PrivacyAttackResult>.unmodifiable(
          results.toList()
            ..sort((a, b) => a.scenarioId.compareTo(b.scenarioId)),
        );

  final int seed;
  final List<PrivacyAttackResult> results;
  final PrivacyAttackCoverage coverage;

  bool get syntheticEvidenceOnly => true;
  bool get passed => results.every((item) => item.passed);

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': privacyAttackSchemaVersion,
        'seed': seed,
        'syntheticEvidenceOnly': syntheticEvidenceOnly,
        'passed': passed,
        'results': results.map((item) => item.toJson()).toList(),
        'coverage': coverage.toJson(),
      };

  String toNormalizedJson() => jsonEncode(_canonicalize(toJson()));

  factory PrivacyAttackReport.fromJson(Map<String, Object?> json) =>
      PrivacyAttackReport(
        seed: json['seed'] as int,
        results: (json['results'] as List)
            .map((item) => PrivacyAttackResult.fromJson(_objectMap(item)))
            .toList(growable: false),
        coverage: PrivacyAttackCoverage.fromJson(_objectMap(json['coverage'])),
      );
  factory PrivacyAttackReport.fromRun({
    required int seed,
    required Iterable<PrivacyAttackScenario> scenarios,
    required Iterable<PrivacyAttackResult> results,
  }) {
    final scenarioList = scenarios.toList(growable: false);
    final resultList = results.toList(growable: false);
    return PrivacyAttackReport(
      seed: seed,
      results: resultList,
      coverage: PrivacyAttackCoverage.fromRun(
        scenarios: scenarioList,
        results: resultList,
      ),
    );
  }
}

class PrivacyAttackSuite {
  const PrivacyAttackSuite();

  Future<PrivacyAttackReport> evaluate({
    required int seed,
    required Iterable<PrivacyAttackScenario> scenarios,
    required PrivacyAttackObserver observer,
    bool requireMandatoryCoverage = false,
  }) async {
    final ordered = scenarios.toList()..sort((a, b) => a.id.compareTo(b.id));
    final results = <PrivacyAttackResult>[];
    for (final scenario in ordered) {
      try {
        final observation = await observer.observe(scenario);
        results.add(_evaluateContainment(scenario, observation));
      } catch (_) {
        results.add(
          PrivacyAttackResult(
            scenarioId: scenario.id,
            family: scenario.family,
            passed: false,
            findingCategory: 'malformed_input',
            reasonCode: 'observer_exception',
            evaluatedAt: scenario.at,
            observation: const PrivacyAttackObservation(
              reason: 'observer_exception',
            ),
            malformedInput: true,
          ),
        );
      }
    }
    var report = PrivacyAttackReport.fromRun(
      seed: seed,
      scenarios: ordered,
      results: results,
    );
    if (requireMandatoryCoverage) {
      report = _withMandatoryCoverage(report, ordered);
    }
    return report;
  }
}

PrivacyAttackResult _evaluateContainment(
  PrivacyAttackScenario scenario,
  PrivacyAttackObservation observation,
) {
  final passed = switch (scenario.containmentContract) {
    PrivacyContainmentContract.allowAuthority => observation.allowed == true,
    PrivacyContainmentContract.denyAuthority => observation.allowed == false,
    PrivacyContainmentContract.allowProjection => observation.projected == true,
    PrivacyContainmentContract.denyProjection => observation.projected == false,
    PrivacyContainmentContract.allowRawExposure =>
      observation.rawValueExposed == true,
    PrivacyContainmentContract.noRawExposure =>
      observation.rawValueExposed == false,
    PrivacyContainmentContract.emitNotification =>
      observation.notificationEmitted == true,
    PrivacyContainmentContract.redactOrSuppressNotification =>
      observation.notificationEmitted == false ||
          observation.notificationRedacted == true,
    PrivacyContainmentContract.requireKeyRotation =>
      observation.keyRotated == true,
    PrivacyContainmentContract.rejectStaleKey =>
      observation.staleKeyActive == false,
    PrivacyContainmentContract.allowRelayDecrypt =>
      observation.relayDecryptAccepted == true,
    PrivacyContainmentContract.rejectRelayDecrypt =>
      observation.relayDecryptAccepted == false,
    PrivacyContainmentContract.rejectRelayIntegrityTamper =>
      observation.relayIntegrityAccepted == false,
  };
  final category = _findingCategory(scenario);
  return PrivacyAttackResult(
    scenarioId: scenario.id,
    family: scenario.family,
    passed: passed,
    findingCategory: category,
    reasonCode: passed ? 'contained' : category,
    evaluatedAt: scenario.at,
    observation: observation,
  );
}

String _findingCategory(PrivacyAttackScenario scenario) {
  if (scenario.family == PrivacyAttackFamily.revocationAndKeyReplay &&
      scenario.containmentContract ==
          PrivacyContainmentContract.rejectStaleKey) {
    return 'stale_key_escape';
  }
  if (scenario.family == PrivacyAttackFamily.relayRecipientBinding &&
      scenario.containmentContract ==
          PrivacyContainmentContract.rejectRelayIntegrityTamper) {
    return 'relay_integrity_violation';
  }
  return switch (scenario.family) {
    PrivacyAttackFamily.identitySubstitution => 'identity_scope_escape',
    PrivacyAttackFamily.actionEscalation => 'action_escalation',
    PrivacyAttackFamily.scopeSubstitution => 'scope_escape',
    PrivacyAttackFamily.temporalReplay => 'temporal_replay_escape',
    PrivacyAttackFamily.composedGrantConfusion => 'composed_gate_bypass',
    PrivacyAttackFamily.relationshipCapabilityEscalation =>
      'relationship_capability_escalation',
    PrivacyAttackFamily.visibilityExfiltration => 'visibility_exfiltration',
    PrivacyAttackFamily.notificationLeakage => 'notification_privacy_violation',
    PrivacyAttackFamily.revocationAndKeyReplay => 'revocation_escape',
    PrivacyAttackFamily.relayRecipientBinding => 'relay_recipient_bypass',
  };
}

Set<String> _scenarioCoverageLabels(PrivacyAttackScenario scenario) {
  final labels = <String>{
    'family:${scenario.family.name}',
    'surface:${scenario.targetSurface}',
    scenario.safeControl ? 'control:safe' : 'control:adversarial',
  };
  for (final tag in scenario.riskTags) {
    if (tag == 'phase8Reuse') labels.add('reuse:phase8');
    if (tag == 'phase9Reuse') labels.add('reuse:phase9');
    if (tag == 'phase10Reuse') labels.add('reuse:phase10');
  }
  for (final dimension in scenario.mutation.dimensions) {
    if (<String>{'category', 'field', 'purpose'}.contains(dimension)) {
      labels.add('scope:$dimension');
    }
    if (<String>{'activation', 'expiry', 'revocation', 'dataWindow'}
        .contains(dimension)) {
      labels.add('temporal:$dimension');
    }
  }
  if (scenario.targetSurface == 'genericPermission') {
    final rawRequest = scenario.payload['request'];
    if (rawRequest is Map) {
      final request = _objectMap(rawRequest);
      final action = request['action'];
      if (action is String) labels.add('action:$action');
    }
  }
  if (scenario.targetSurface == 'sharePolicy') {
    final action = scenario.payload['requestedAction'];
    if (action is String) labels.add('action:$action');
  }
  if (scenario.targetSurface == 'composedAccess') {
    final action = scenario.payload['genericAction'];
    final capability = scenario.payload['relationshipCapability'];
    if (action is String) labels.add('action:$action');
    if (capability is String) labels.add('relationshipCapability:$capability');
  }
  if (scenario.targetSurface == 'relationshipPermission' ||
      scenario.targetSurface == 'relationshipProjection') {
    final capability = scenario.payload['capability'];
    if (capability is String) labels.add('relationshipCapability:$capability');
  }
  if (scenario.targetSurface == 'relationshipProjection') {
    final item = _requiredMap(scenario.payload, 'item');
    final visibility = item['visibility'];
    if (visibility is String) labels.add('visibility:$visibility');
  }
  if (scenario.targetSurface == 'relationshipNotification') {
    labels.add('relationshipCapability:notify');
    final mode = scenario.payload['mode'];
    if (mode is String) labels.add('notification:$mode');
  }
  if (scenario.targetSurface == 'revocationKeyState') {
    labels.add('revocation:keyRotation');
    if (scenario.mutation.dimensions.contains('staleKey')) {
      labels.add('revocation:staleKey');
    }
  }
  if (scenario.targetSurface == 'relayTransport') {
    if (scenario.mutation.dimensions.contains('recipient')) {
      labels.add('relay:recipient');
    }
    if (scenario.mutation.dimensions.contains('associatedData') ||
        scenario.mutation.dimensions.contains('ciphertext')) {
      labels.add('relay:integrity');
    }
  }
  return labels;
}

Set<String> get _mandatoryPrivacyAttackCoverageLabels => <String>{
      for (final family in PrivacyAttackFamily.values) 'family:${family.name}',
      'control:safe',
      'control:adversarial',
      'action:view',
      'action:notify',
      'action:backup',
      'action:export',
      'scope:category',
      'scope:field',
      'scope:purpose',
      'temporal:activation',
      'temporal:expiry',
      'temporal:revocation',
      'temporal:dataWindow',
      'relationshipCapability:view',
      'relationshipCapability:notify',
      'relationshipCapability:relationshipIntelligence',
      'relationshipCapability:playful',
      'relationshipCapability:intimacy',
      'visibility:private',
      'visibility:engineOnly',
      'visibility:abstractShared',
      'visibility:fullyShared',
      'notification:generic',
      'notification:categoryOnly',
      'notification:detailedWhenUnlocked',
      'surface:genericPermission',
      'surface:sharePolicy',
      'surface:composedAccess',
      'surface:relationshipPermission',
      'surface:relationshipProjection',
      'surface:relationshipNotification',
      'surface:revocationKeyState',
      'surface:relayTransport',
      'revocation:keyRotation',
      'revocation:staleKey',
      'relay:recipient',
      'relay:integrity',
      'reuse:phase8',
      'reuse:phase9',
      'reuse:phase10',
    };

PrivacyAttackReport _withMandatoryCoverage(
  PrivacyAttackReport report,
  List<PrivacyAttackScenario> scenarios,
) {
  final covered = <String>{
    for (final scenario in scenarios) ..._scenarioCoverageLabels(scenario),
  };
  final gaps = _mandatoryPrivacyAttackCoverageLabels
      .where((label) => !covered.contains(label))
      .toList()
    ..sort();
  if (gaps.isEmpty) return report;
  final reason = 'coverage_gap:${gaps.join('|')}';
  final gap = PrivacyAttackResult(
    scenarioId: 'coverage-gap',
    family: PrivacyAttackFamily.identitySubstitution,
    passed: false,
    findingCategory: 'coverage_gap',
    reasonCode: reason,
    evaluatedAt:
        scenarios.isEmpty ? DateTime.utc(2026, 9, 16) : scenarios.first.at,
    observation: PrivacyAttackObservation(reason: reason),
  );
  return PrivacyAttackReport(
    seed: report.seed,
    results: <PrivacyAttackResult>[...report.results, gap],
    coverage: report.coverage,
  );
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return <String, Object?>{
      for (final entry in entries)
        entry.key.toString(): _canonicalize(entry.value),
    };
  }
  if (value is Set) {
    final items = value.map(_canonicalize).toList()
      ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    return items;
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) throw ArgumentError('Expected object map');
  return <String, Object?>{
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

Set<String> _stringSet(Object? value) {
  if (value is! List) throw ArgumentError('Expected string list');
  return value.map((item) {
    if (item is! String) throw ArgumentError('Expected string list');
    return item;
  }).toSet();
}

Map<String, int> _intMap(Object? value) {
  final map = _objectMap(value);
  return <String, int>{
    for (final entry in map.entries) entry.key: entry.value as int,
  };
}

T _enumByName<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is! String) throw ArgumentError('$field is required');
  return values.firstWhere(
    (item) => item.name == value,
    orElse: () => throw ArgumentError('Unsupported $field: $value'),
  );
}

DateTime _parseUtc(Object? value, String field) {
  if (value is! String) throw ArgumentError('$field is required');
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw ArgumentError('$field must be UTC');
  }
  return parsed;
}

void _requireText(String value, String field) {
  if (value.trim().isEmpty) throw ArgumentError('$field must not be blank');
}

class ProductionPrivacyAttackObserver extends PrivacyAttackObserver {
  const ProductionPrivacyAttackObserver({
    this.permissionEvaluator = const PermissionEvaluator(),
    this.privacySimulator = const PrivacySimulator(),
    this.sharePolicy = const SharePolicy(),
  });

  final PermissionEvaluator permissionEvaluator;
  final PrivacySimulator privacySimulator;
  final SharePolicy sharePolicy;

  @override
  Future<PrivacyAttackObservation> observe(
      PrivacyAttackScenario scenario) async {
    return switch (scenario.targetSurface) {
      'genericPermission' => _observeGenericPermission(scenario),
      'sharePolicy' => _observeSharePolicy(scenario),
      'composedAccess' => _observeComposedAccess(scenario),
      'relationshipPermission' => _observeRelationshipPermission(scenario),
      'relationshipProjection' => _observeRelationshipProjection(scenario),
      'relationshipNotification' => _observeRelationshipNotification(scenario),
      'revocationKeyState' => await _observeRevocationKeyState(scenario),
      'relayTransport' => await _observeRelayTransport(scenario),
      _ => throw ArgumentError(
          'Unsupported target surface: ${scenario.targetSurface}',
        ),
    };
  }

  PrivacyAttackObservation _observeGenericPermission(
    PrivacyAttackScenario scenario,
  ) {
    final requestMap = _requiredMap(scenario.payload, 'request');
    final grants = _permissionGrants(scenario.payload['grants']);
    final request = PermissionRequest(
      ownerId: scenario.ownerId,
      recipientId: scenario.attemptedRecipientId,
      action: _enumByName(
        PermissionAction.values,
        requestMap['action'],
        'request.action',
      ),
      category: _requiredString(requestMap, 'category'),
      field: _optionalString(requestMap['field']),
      purpose: _optionalString(requestMap['purpose']),
      at: scenario.at,
      resourceObservedAt: _optionalUtc(
        requestMap['resourceObservedAt'],
        'request.resourceObservedAt',
      ),
    );
    final decision = permissionEvaluator.evaluate(
      request: request,
      grants: grants,
    );
    final simulated = privacySimulator
        .simulate(requests: <PermissionRequest>[request], grants: grants)
        .entries
        .single
        .decision;
    if (decision.allowed != simulated.allowed ||
        decision.matchedGrantId != simulated.matchedGrantId) {
      throw StateError('privacy simulator diverged from permission evaluator');
    }
    return PrivacyAttackObservation(
      allowed: decision.allowed,
      matchedGenericGrantId: decision.matchedGrantId,
      reason: decision.reason,
    );
  }

  PrivacyAttackObservation _observeSharePolicy(
    PrivacyAttackScenario scenario,
  ) {
    final grants = _permissionGrants(scenario.payload['grants']);
    final decision = sharePolicy.evaluate(
      ownerId: scenario.ownerId,
      recipientId: scenario.attemptedRecipientId,
      category: _requiredString(scenario.payload, 'category'),
      at: scenario.at,
      grants: grants,
      resourceObservedAt: _optionalUtc(
        scenario.payload['resourceObservedAt'],
        'resourceObservedAt',
      ),
    );
    final requestedAction =
        _requiredString(scenario.payload, 'requestedAction');
    final allowed = switch (requestedAction) {
      'view' => decision.canView,
      'notify' => decision.canNotify,
      'backup' => decision.canBackup,
      _ => throw ArgumentError('Unsupported share action: $requestedAction'),
    };
    return PrivacyAttackObservation(allowed: allowed, reason: 'share_policy');
  }
}

Map<String, Object?> _requiredMap(
  Map<String, Object?> map,
  String key,
) {
  final value = map[key];
  if (value is! Map) throw ArgumentError('$key must be an object');
  return _objectMap(value);
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw ArgumentError('$key is required');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw ArgumentError('Expected non-empty string');
  }
  return value;
}

DateTime? _optionalUtc(Object? value, String field) {
  if (value == null) return null;
  return _parseUtc(value, field);
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) throw ArgumentError('Expected list');
  return value.map(_objectMap).toList(growable: false);
}

List<PermissionGrant> _permissionGrants(Object? value) {
  return _mapList(value).map((json) {
    final scopeJson = _requiredMap(json, 'scope');
    final actions = _stringSet(json['actions'])
        .map((name) => _enumByName(PermissionAction.values, name, 'action'))
        .toSet();
    return PermissionGrant(
      id: _requiredString(json, 'id'),
      ownerId: _requiredString(json, 'ownerId'),
      recipientId: _requiredString(json, 'recipientId'),
      recipientKind: _enumByName(
        RecipientKind.values,
        json['recipientKind'],
        'recipientKind',
      ),
      actions: actions,
      scope: PermissionScope(
        categories: _stringSet(scopeJson['categories']),
        fields: _stringSet(scopeJson['fields']),
        purposes: _stringSet(scopeJson['purposes']),
        validFrom: _optionalUtc(scopeJson['validFrom'], 'scope.validFrom'),
        validUntil: _optionalUtc(scopeJson['validUntil'], 'scope.validUntil'),
        dataFrom: _optionalUtc(scopeJson['dataFrom'], 'scope.dataFrom'),
        dataUntil: _optionalUtc(scopeJson['dataUntil'], 'scope.dataUntil'),
      ),
      createdAt: _parseUtc(json['createdAt'], 'createdAt'),
      revokedAt: _optionalUtc(json['revokedAt'], 'revokedAt'),
      version: json['version'] as int? ?? 1,
    );
  }).toList(growable: false);
}

List<PrivacyAttackScenario> buildCanonicalPrivacyAttackScenarios(int seed) =>
    const PrivacyAttackGenerator().generateCanonical(seed);

class PrivacyAttackGenerator {
  const PrivacyAttackGenerator();

  List<PrivacyAttackScenario> generateCanonical(int seed) {
    final scenarios = <PrivacyAttackScenario>[];
    scenarios.addAll(_identityScenarios(seed));
    scenarios.addAll(_actionScenarios(seed));
    scenarios.addAll(_scopeScenarios(seed));
    scenarios.addAll(_temporalScenarios(seed));
    scenarios.addAll(_composedScenarios(seed));
    scenarios.addAll(_relationshipCapabilityScenarios(seed));
    scenarios.addAll(_visibilityScenarios(seed));
    scenarios.addAll(_notificationScenarios(seed));
    scenarios.addAll(_revocationKeyScenarios(seed));
    scenarios.addAll(_relayScenarios(seed));
    scenarios.sort((a, b) => a.id.compareTo(b.id));
    return List<PrivacyAttackScenario>.unmodifiable(scenarios);
  }
}

const String _owner = 'patient-1';
const String _recipient = 'partner-1';
const String _otherRecipient = 'partner-2';
final DateTime _baseAt = DateTime.utc(2026, 9, 16, 12);

Map<String, Object?> _grant({
  required String id,
  required String action,
  String ownerId = _owner,
  String recipientId = _recipient,
  Set<String> categories = const <String>{'cycle'},
  Set<String> fields = const <String>{},
  Set<String> purposes = const <String>{},
  DateTime? validFrom,
  DateTime? validUntil,
  DateTime? dataFrom,
  DateTime? dataUntil,
  DateTime? revokedAt,
}) =>
    <String, Object?>{
      'id': id,
      'ownerId': ownerId,
      'recipientId': recipientId,
      'recipientKind': 'partner',
      'actions': <String>[action],
      'scope': <String, Object?>{
        'categories': categories.toList()..sort(),
        'fields': fields.toList()..sort(),
        'purposes': purposes.toList()..sort(),
        'validFrom': validFrom?.toIso8601String(),
        'validUntil': validUntil?.toIso8601String(),
        'dataFrom': dataFrom?.toIso8601String(),
        'dataUntil': dataUntil?.toIso8601String(),
      },
      'createdAt': DateTime.utc(2026, 9, 16, 10).toIso8601String(),
      'revokedAt': revokedAt?.toIso8601String(),
      'version': 1,
    };
PrivacyAttackScenario _genericCase({
  required String id,
  required PrivacyAttackFamily family,
  required String action,
  required Map<String, Object?> grant,
  required bool safeControl,
  String? sourceControlId,
  DateTime? at,
  String ownerId = _owner,
  String recipientId = _recipient,
  String category = 'cycle',
  String? field,
  String? purpose,
  DateTime? resourceObservedAt,
  Set<String> dimensions = const <String>{'control'},
  int seed = 20260916,
}) {
  final sourceId = sourceControlId ?? id;
  return PrivacyAttackScenario(
    id: id,
    sourceControlId: sourceId,
    schemaVersion: privacyAttackSchemaVersion,
    seed: seed,
    at: at ?? _baseAt,
    ownerId: ownerId,
    intendedRecipientId: _recipient,
    attemptedRecipientId: recipientId,
    family: family,
    targetSurface: 'genericPermission',
    mutation: PrivacyAttackMutation(
      id: 'mutation-$id',
      family: family,
      sourceControlId: sourceId,
      dimensions: dimensions,
      before: <String, Object?>{'sourceControlId': sourceId},
      after: <String, Object?>{'scenarioId': id},
      paired: dimensions.length > 1,
    ),
    containmentContract: safeControl
        ? PrivacyContainmentContract.allowAuthority
        : PrivacyContainmentContract.denyAuthority,
    riskTags: <String>{
      family.name,
      ...dimensions,
      'phase9Reuse',
    },
    payload: <String, Object?>{
      'request': <String, Object?>{
        'action': action,
        'category': category,
        'field': field,
        'purpose': purpose,
        'resourceObservedAt': resourceObservedAt?.toIso8601String(),
      },
      'grants': <Object?>[grant],
    },
    safeControl: safeControl,
    adversarial: !safeControl,
  );
}

List<PrivacyAttackScenario> _identityScenarios(int seed) {
  final grant = _grant(id: 'grant-view', action: 'view');
  return <PrivacyAttackScenario>[
    _genericCase(
      id: 'control-view',
      family: PrivacyAttackFamily.identitySubstitution,
      action: 'view',
      grant: grant,
      safeControl: true,
      seed: seed,
    ),
    _genericCase(
      id: 'attack-wrong-owner',
      sourceControlId: 'control-view',
      family: PrivacyAttackFamily.identitySubstitution,
      action: 'view',
      grant: grant,
      ownerId: 'patient-2',
      safeControl: false,
      dimensions: const <String>{'owner'},
      seed: seed,
    ),
    _genericCase(
      id: 'attack-wrong-recipient',
      sourceControlId: 'control-view',
      family: PrivacyAttackFamily.identitySubstitution,
      action: 'view',
      grant: grant,
      recipientId: _otherRecipient,
      safeControl: false,
      dimensions: const <String>{'recipient'},
      seed: seed,
    ),
  ];
}

List<PrivacyAttackScenario> _actionScenarios(int seed) {
  final scenarios = <PrivacyAttackScenario>[];
  for (final action in <String>['view', 'notify', 'backup', 'export']) {
    scenarios.add(
      _genericCase(
        id: 'control-action-$action',
        family: PrivacyAttackFamily.actionEscalation,
        action: action,
        grant: _grant(id: 'grant-$action', action: action),
        safeControl: true,
        seed: seed,
      ),
    );
  }
  final attacks = <(String, String, String)>[
    ('view', 'notify', 'attack-view-to-notify'),
    ('view', 'backup', 'attack-view-to-backup'),
    ('view', 'export', 'attack-view-to-export'),
    ('notify', 'view', 'attack-notify-to-view'),
    ('backup', 'view', 'attack-backup-to-view'),
    ('export', 'view', 'attack-export-to-view'),
  ];
  for (final (grantAction, requestAction, id) in attacks) {
    scenarios.add(
      _genericCase(
        id: id,
        sourceControlId: 'control-action-$grantAction',
        family: PrivacyAttackFamily.actionEscalation,
        action: requestAction,
        grant: _grant(id: 'grant-$grantAction', action: grantAction),
        safeControl: false,
        dimensions: const <String>{'action'},
        seed: seed,
      ),
    );
  }
  scenarios.addAll(_sharePolicyActionScenarios(seed));
  return scenarios;
}

List<PrivacyAttackScenario> _sharePolicyActionScenarios(int seed) {
  final grant = _grant(id: 'grant-share-view', action: 'view');
  PrivacyAttackScenario build({
    required String id,
    required String requestedAction,
    required bool safeControl,
  }) {
    const family = PrivacyAttackFamily.actionEscalation;
    final sourceId = safeControl ? id : 'control-share-view';
    return PrivacyAttackScenario(
      id: id,
      sourceControlId: sourceId,
      schemaVersion: privacyAttackSchemaVersion,
      seed: seed,
      at: _baseAt,
      ownerId: _owner,
      intendedRecipientId: _recipient,
      attemptedRecipientId: _recipient,
      family: family,
      targetSurface: 'sharePolicy',
      mutation: PrivacyAttackMutation(
        id: 'mutation-$id',
        family: family,
        sourceControlId: sourceId,
        dimensions: const <String>{'action'},
        before: const <String, Object?>{'action': 'view'},
        after: <String, Object?>{'action': requestedAction},
        paired: false,
      ),
      containmentContract: safeControl
          ? PrivacyContainmentContract.allowAuthority
          : PrivacyContainmentContract.denyAuthority,
      riskTags: const <String>{'action', 'phase9Reuse'},
      payload: <String, Object?>{
        'category': 'cycle',
        'requestedAction': requestedAction,
        'grants': <Object?>[grant],
      },
      safeControl: safeControl,
      adversarial: !safeControl,
    );
  }

  return <PrivacyAttackScenario>[
    build(
      id: 'control-share-view',
      requestedAction: 'view',
      safeControl: true,
    ),
    build(
      id: 'attack-share-view-to-notify',
      requestedAction: 'notify',
      safeControl: false,
    ),
  ];
}

List<PrivacyAttackScenario> _scopeScenarios(int seed) {
  final grant = _grant(
    id: 'grant-scope',
    action: 'view',
    fields: const <String>{'phase'},
    purposes: const <String>{'care'},
  );
  return <PrivacyAttackScenario>[
    _genericCase(
      id: 'control-scope',
      family: PrivacyAttackFamily.scopeSubstitution,
      action: 'view',
      grant: grant,
      field: 'phase',
      purpose: 'care',
      safeControl: true,
      seed: seed,
    ),
    _genericCase(
      id: 'attack-wrong-category',
      sourceControlId: 'control-scope',
      family: PrivacyAttackFamily.scopeSubstitution,
      action: 'view',
      grant: grant,
      category: 'fertility',
      field: 'phase',
      purpose: 'care',
      safeControl: false,
      dimensions: const <String>{'category'},
      seed: seed,
    ),
    _genericCase(
      id: 'attack-wrong-field',
      sourceControlId: 'control-scope',
      family: PrivacyAttackFamily.scopeSubstitution,
      action: 'view',
      grant: grant,
      field: 'symptom',
      purpose: 'care',
      safeControl: false,
      dimensions: const <String>{'field'},
      seed: seed,
    ),
    _genericCase(
      id: 'attack-wrong-purpose',
      sourceControlId: 'control-scope',
      family: PrivacyAttackFamily.scopeSubstitution,
      action: 'view',
      grant: grant,
      field: 'phase',
      purpose: 'research',
      safeControl: false,
      dimensions: const <String>{'purpose'},
      seed: seed,
    ),
  ];
}

List<PrivacyAttackScenario> _temporalScenarios(int seed) {
  final activation = DateTime.utc(2026, 9, 16, 11);
  final expiry = DateTime.utc(2026, 9, 16, 13);
  final boundedGrant = _grant(
    id: 'grant-temporal',
    action: 'view',
    validFrom: activation,
    validUntil: expiry,
  );
  final revocation = DateTime.utc(2026, 9, 16, 12);
  final revokedGrant = _grant(
    id: 'grant-revoked',
    action: 'view',
    revokedAt: revocation,
  );
  final dataFrom = DateTime.utc(2026, 9, 10);
  final dataUntil = DateTime.utc(2026, 9, 15);
  final historicalGrant = _grant(
    id: 'grant-history',
    action: 'view',
    dataFrom: dataFrom,
    dataUntil: dataUntil,
  );
  return <PrivacyAttackScenario>[
    _genericCase(
      id: 'control-at-activation',
      family: PrivacyAttackFamily.temporalReplay,
      action: 'view',
      grant: boundedGrant,
      at: activation,
      safeControl: true,
      seed: seed,
    ),
    _genericCase(
      id: 'attack-before-activation',
      sourceControlId: 'control-at-activation',
      family: PrivacyAttackFamily.temporalReplay,
      action: 'view',
      grant: boundedGrant,
      at: activation.subtract(const Duration(seconds: 1)),
      safeControl: false,
      dimensions: const <String>{'activation'},
      seed: seed,
    ),
    _genericCase(
      id: 'attack-exact-expiry',
      sourceControlId: 'control-at-activation',
      family: PrivacyAttackFamily.temporalReplay,
      action: 'view',
      grant: boundedGrant,
      at: expiry,
      safeControl: false,
      dimensions: const <String>{'expiry'},
      seed: seed,
    ),
    _genericCase(
      id: 'control-before-revocation',
      family: PrivacyAttackFamily.temporalReplay,
      action: 'view',
      grant: revokedGrant,
      at: revocation.subtract(const Duration(seconds: 1)),
      safeControl: true,
      seed: seed,
    ),
    _genericCase(
      id: 'attack-exact-revocation',
      sourceControlId: 'control-before-revocation',
      family: PrivacyAttackFamily.temporalReplay,
      action: 'view',
      grant: revokedGrant,
      at: revocation,
      safeControl: false,
      dimensions: const <String>{'revocation'},
      seed: seed,
    ),
    _genericCase(
      id: 'attack-after-revocation',
      sourceControlId: 'control-before-revocation',
      family: PrivacyAttackFamily.temporalReplay,
      action: 'view',
      grant: revokedGrant,
      at: revocation.add(const Duration(seconds: 1)),
      safeControl: false,
      dimensions: const <String>{'revocation'},
      seed: seed,
    ),
    _genericCase(
      id: 'attack-before-data-from',
      sourceControlId: 'control-at-data-from',
      family: PrivacyAttackFamily.temporalReplay,
      action: 'view',
      grant: historicalGrant,
      resourceObservedAt: dataFrom.subtract(const Duration(seconds: 1)),
      safeControl: false,
      dimensions: const <String>{'dataWindow'},
      seed: seed,
    ),
    _genericCase(
      id: 'control-at-data-from',
      family: PrivacyAttackFamily.temporalReplay,
      action: 'view',
      grant: historicalGrant,
      resourceObservedAt: dataFrom,
      safeControl: true,
      seed: seed,
    ),
    _genericCase(
      id: 'control-at-data-until',
      family: PrivacyAttackFamily.temporalReplay,
      action: 'view',
      grant: historicalGrant,
      resourceObservedAt: dataUntil,
      safeControl: true,
      seed: seed,
    ),
    _genericCase(
      id: 'attack-after-data-until',
      sourceControlId: 'control-at-data-until',
      family: PrivacyAttackFamily.temporalReplay,
      action: 'view',
      grant: historicalGrant,
      resourceObservedAt: dataUntil.add(const Duration(seconds: 1)),
      safeControl: false,
      dimensions: const <String>{'dataWindow'},
      seed: seed,
    ),
  ];
}

PrivacyAttackObservation _observeComposedAccess(
  PrivacyAttackScenario scenario,
) {
  final decision = const RelationshipAccessGate().evaluate(
    ownerId: scenario.ownerId,
    recipientId: scenario.attemptedRecipientId,
    genericCategory: _requiredString(scenario.payload, 'genericCategory'),
    relationshipCategory:
        _requiredString(scenario.payload, 'relationshipCategory'),
    genericAction: _enumByName(
      PermissionAction.values,
      scenario.payload['genericAction'],
      'genericAction',
    ),
    relationshipCapability: _enumByName(
      RelationshipCapability.values,
      scenario.payload['relationshipCapability'],
      'relationshipCapability',
    ),
    at: scenario.at,
    genericGrants: _permissionGrants(scenario.payload['genericGrants']),
    relationshipGrants:
        _relationshipGrants(scenario.payload['relationshipGrants']),
  );
  return PrivacyAttackObservation(
    allowed: decision.allowed,
    matchedGenericGrantId: decision.genericGrantId,
    matchedRelationshipGrantId: decision.relationshipGrantId,
    reason: decision.reason,
  );
}

PrivacyAttackObservation _observeRelationshipPermission(
  PrivacyAttackScenario scenario,
) {
  final decision = const RelationshipPermissionFirewall().evaluate(
    request: RelationshipAccessRequest(
      ownerId: scenario.ownerId,
      recipientId: scenario.attemptedRecipientId,
      category: _requiredString(scenario.payload, 'category'),
      capability: _enumByName(
        RelationshipCapability.values,
        scenario.payload['capability'],
        'capability',
      ),
      at: scenario.at,
    ),
    grants: _relationshipGrants(scenario.payload['relationshipGrants']),
  );
  return PrivacyAttackObservation(
    allowed: decision.allowed,
    matchedRelationshipGrantId: decision.matchedGrantId,
    effectiveVisibility: decision.visibility?.name,
    reason: decision.reason,
  );
}

PrivacyAttackObservation _observeRelationshipProjection(
  PrivacyAttackScenario scenario,
) {
  final item = _requiredMap(scenario.payload, 'item');
  final projection = const RelationshipContextProjector().project<Object?>(
    item: RelationshipContextItem<Object?>(
      ownerId: scenario.ownerId,
      category: _requiredString(item, 'category'),
      value: item['value'],
      observedAt: _parseUtc(item['observedAt'], 'item.observedAt'),
      visibility: _enumByName(
        RelationshipVisibility.values,
        item['visibility'],
        'item.visibility',
      ),
    ),
    recipientId: scenario.attemptedRecipientId,
    capability: _enumByName(
      RelationshipCapability.values,
      scenario.payload['capability'],
      'capability',
    ),
    at: scenario.at,
    grants: _relationshipGrants(scenario.payload['relationshipGrants']),
  );
  return PrivacyAttackObservation(
    projected: projection != null,
    rawValueExposed: projection?.exposesRawValue ?? false,
    effectiveVisibility: projection?.visibility.name,
    reason: projection == null ? 'not_projected' : 'projected',
  );
}

PrivacyAttackObservation _observeRelationshipNotification(
  PrivacyAttackScenario scenario,
) {
  final notification = const RelationshipNotificationPipeline().present(
    request: RelationshipNotificationRequest(
      ownerId: scenario.ownerId,
      recipientId: scenario.attemptedRecipientId,
      category: _requiredString(scenario.payload, 'category'),
      categoryLabel: _requiredString(scenario.payload, 'categoryLabel'),
      detail: _requiredString(scenario.payload, 'detail'),
      kind: _enumByName(
        RelationshipNotificationKind.values,
        scenario.payload['kind'],
        'kind',
      ),
      at: scenario.at,
    ),
    mode: _enumByName(
      NotificationPrivacyMode.values,
      scenario.payload['mode'],
      'mode',
    ),
    deviceUnlocked: scenario.payload['deviceUnlocked'] as bool,
    grants: _relationshipGrants(scenario.payload['relationshipGrants']),
  );
  return PrivacyAttackObservation(
    notificationEmitted: notification != null,
    notificationRedacted: notification?.redacted,
    reason: notification == null
        ? 'suppressed'
        : notification.redacted
            ? 'redacted'
            : 'detailed',
  );
}

List<RelationshipCategoryGrant> _relationshipGrants(Object? value) {
  return _mapList(value).map((json) {
    final capabilities = _stringSet(json['capabilities'])
        .map(
          (name) => _enumByName(
            RelationshipCapability.values,
            name,
            'relationshipCapability',
          ),
        )
        .toSet();
    return RelationshipCategoryGrant(
      id: _requiredString(json, 'id'),
      ownerId: _requiredString(json, 'ownerId'),
      recipientId: _requiredString(json, 'recipientId'),
      category: _requiredString(json, 'category'),
      capabilities: capabilities,
      visibility: _enumByName(
        RelationshipVisibility.values,
        json['visibility'],
        'visibility',
      ),
      createdAt: _parseUtc(json['createdAt'], 'createdAt'),
      validUntil: _optionalUtc(json['validUntil'], 'validUntil'),
      revokedAt: _optionalUtc(json['revokedAt'], 'revokedAt'),
      version: json['version'] as int? ?? 1,
    );
  }).toList(growable: false);
}

Map<String, Object?> _relationshipGrant({
  required String id,
  required Set<String> capabilities,
  String ownerId = _owner,
  String recipientId = _recipient,
  String category = 'relationship.context',
  String visibility = 'engineOnly',
}) =>
    <String, Object?>{
      'id': id,
      'ownerId': ownerId,
      'recipientId': recipientId,
      'category': category,
      'capabilities': capabilities.toList()..sort(),
      'visibility': visibility,
      'createdAt': DateTime.utc(2026, 9, 16, 10).toIso8601String(),
      'version': 1,
    };

PrivacyAttackMutation _mutation({
  required String id,
  required PrivacyAttackFamily family,
  required String sourceControlId,
  required Set<String> dimensions,
}) =>
    PrivacyAttackMutation(
      id: 'mutation-$id',
      family: family,
      sourceControlId: sourceControlId,
      dimensions: dimensions,
      before: <String, Object?>{'sourceControlId': sourceControlId},
      after: <String, Object?>{'scenarioId': id},
      paired: dimensions.length > 1,
    );

List<PrivacyAttackScenario> _composedScenarios(int seed) {
  const family = PrivacyAttackFamily.composedGrantConfusion;
  final genericGrant = _grant(id: 'grant-composed-view', action: 'view');
  final relationshipGrant = _relationshipGrant(
    id: 'relationship-composed-view',
    capabilities: const <String>{'view'},
    visibility: 'fullyShared',
  );

  PrivacyAttackScenario build({
    required String id,
    required bool safeControl,
    String relationshipCategory = 'relationship.context',
    List<Object?>? genericGrants,
    List<Object?>? relationshipGrants,
    Set<String> dimensions = const <String>{'control'},
  }) {
    final sourceId = safeControl ? id : 'control-composed-view';
    return PrivacyAttackScenario(
      id: id,
      sourceControlId: sourceId,
      schemaVersion: privacyAttackSchemaVersion,
      seed: seed,
      at: _baseAt,
      ownerId: _owner,
      intendedRecipientId: _recipient,
      attemptedRecipientId: _recipient,
      family: family,
      targetSurface: 'composedAccess',
      mutation: _mutation(
        id: id,
        family: family,
        sourceControlId: sourceId,
        dimensions: dimensions,
      ),
      containmentContract: safeControl
          ? PrivacyContainmentContract.allowAuthority
          : PrivacyContainmentContract.denyAuthority,
      riskTags: const <String>{'composed', 'phase9Reuse', 'phase10Reuse'},
      payload: <String, Object?>{
        'genericCategory': 'cycle',
        'relationshipCategory': relationshipCategory,
        'genericAction': 'view',
        'relationshipCapability': 'view',
        'genericGrants': genericGrants ?? <Object?>[genericGrant],
        'relationshipGrants':
            relationshipGrants ?? <Object?>[relationshipGrant],
      },
      safeControl: safeControl,
      adversarial: !safeControl,
    );
  }

  return <PrivacyAttackScenario>[
    build(id: 'control-composed-view', safeControl: true),
    build(
      id: 'attack-composed-mixed-recipient',
      safeControl: false,
      relationshipGrants: <Object?>[
        _relationshipGrant(
          id: 'relationship-wrong-recipient',
          capabilities: const <String>{'view'},
          recipientId: _otherRecipient,
          visibility: 'fullyShared',
        ),
      ],
      dimensions: const <String>{'recipient'},
    ),
    build(
      id: 'attack-composed-wrong-category',
      safeControl: false,
      relationshipCategory: 'relationship.other',
      dimensions: const <String>{'category'},
    ),
    build(
      id: 'attack-composed-missing-generic',
      safeControl: false,
      genericGrants: const <Object?>[],
      dimensions: const <String>{'genericGrant'},
    ),
  ];
}

List<PrivacyAttackScenario> _relationshipCapabilityScenarios(int seed) {
  const family = PrivacyAttackFamily.relationshipCapabilityEscalation;
  final viewGrant = _relationshipGrant(
    id: 'relationship-view-only',
    capabilities: const <String>{'view'},
    visibility: 'fullyShared',
  );

  PrivacyAttackScenario build({
    required String id,
    required String capability,
    required bool safeControl,
    String ownerId = _owner,
    String recipientId = _recipient,
    List<Object?>? grants,
    String sourceControlId = 'control-relationship-view',
    Set<String> dimensions = const <String>{'capability'},
  }) {
    final sourceId = safeControl ? id : sourceControlId;
    return PrivacyAttackScenario(
      id: id,
      sourceControlId: sourceId,
      schemaVersion: privacyAttackSchemaVersion,
      seed: seed,
      at: _baseAt,
      ownerId: ownerId,
      intendedRecipientId: recipientId,
      attemptedRecipientId: recipientId,
      family: family,
      targetSurface: 'relationshipPermission',
      mutation: _mutation(
        id: id,
        family: family,
        sourceControlId: sourceId,
        dimensions: dimensions,
      ),
      containmentContract: safeControl
          ? PrivacyContainmentContract.allowAuthority
          : PrivacyContainmentContract.denyAuthority,
      riskTags: const <String>{'relationshipCapability', 'phase10Reuse'},
      payload: <String, Object?>{
        'category': 'relationship.context',
        'capability': capability,
        'relationshipGrants': grants ?? <Object?>[viewGrant],
      },
      safeControl: safeControl,
      adversarial: !safeControl,
    );
  }

  final intimacyGrant = _relationshipGrant(
    id: 'relationship-intimacy-one-way',
    capabilities: const <String>{'intimacy'},
    visibility: 'engineOnly',
  );
  return <PrivacyAttackScenario>[
    build(
        id: 'control-relationship-view', capability: 'view', safeControl: true),
    build(
      id: 'attack-view-to-intelligence',
      capability: 'relationshipIntelligence',
      safeControl: false,
    ),
    build(
        id: 'attack-view-to-playful',
        capability: 'playful',
        safeControl: false),
    build(
        id: 'attack-view-to-intimacy',
        capability: 'intimacy',
        safeControl: false),
    build(
      id: 'control-relationship-intimacy',
      capability: 'intimacy',
      safeControl: true,
      grants: <Object?>[intimacyGrant],
    ),
    build(
      id: 'attack-one-direction-intimacy-reverse',
      capability: 'intimacy',
      safeControl: false,
      ownerId: _recipient,
      recipientId: _owner,
      grants: <Object?>[intimacyGrant],
      sourceControlId: 'control-relationship-intimacy',
      dimensions: const <String>{'direction'},
    ),
  ];
}

List<PrivacyAttackScenario> _visibilityScenarios(int seed) {
  const family = PrivacyAttackFamily.visibilityExfiltration;
  final grant = _relationshipGrant(
    id: 'relationship-projection-view',
    capabilities: const <String>{'view'},
    visibility: 'fullyShared',
  );

  PrivacyAttackScenario build({
    required String id,
    required String visibility,
    required bool safeControl,
  }) {
    final sourceId = safeControl ? id : 'control-projection-fully-shared';
    return PrivacyAttackScenario(
      id: id,
      sourceControlId: sourceId,
      schemaVersion: privacyAttackSchemaVersion,
      seed: seed,
      at: _baseAt,
      ownerId: _owner,
      intendedRecipientId: _recipient,
      attemptedRecipientId: _recipient,
      family: family,
      targetSurface: 'relationshipProjection',
      mutation: _mutation(
        id: id,
        family: family,
        sourceControlId: sourceId,
        dimensions: <String>{safeControl ? 'control' : 'visibility'},
      ),
      containmentContract: safeControl
          ? PrivacyContainmentContract.allowRawExposure
          : PrivacyContainmentContract.noRawExposure,
      riskTags: const <String>{'visibility', 'phase9Reuse', 'phase10Reuse'},
      payload: <String, Object?>{
        'capability': 'view',
        'item': <String, Object?>{
          'category': 'relationship.context',
          'value': 'private-value',
          'observedAt':
              _baseAt.subtract(const Duration(hours: 1)).toIso8601String(),
          'visibility': visibility,
        },
        'relationshipGrants': <Object?>[grant],
      },
      safeControl: safeControl,
      adversarial: !safeControl,
    );
  }

  return <PrivacyAttackScenario>[
    build(
      id: 'control-projection-fully-shared',
      visibility: 'fullyShared',
      safeControl: true,
    ),
    build(
        id: 'attack-projection-private',
        visibility: 'private',
        safeControl: false),
    build(
        id: 'attack-projection-engine-only',
        visibility: 'engineOnly',
        safeControl: false),
    build(
        id: 'attack-projection-abstract-shared',
        visibility: 'abstractShared',
        safeControl: false),
  ];
}

List<PrivacyAttackScenario> _notificationScenarios(int seed) {
  const family = PrivacyAttackFamily.notificationLeakage;
  final notifyGrant = _relationshipGrant(
    id: 'relationship-notify',
    capabilities: const <String>{'notify'},
    visibility: 'engineOnly',
  );

  PrivacyAttackScenario build({
    required String id,
    required String mode,
    required bool deviceUnlocked,
    required String kind,
    required bool safeControl,
    List<Object?>? grants,
  }) {
    final sourceId =
        safeControl ? id : 'control-notification-detailed-unlocked';
    return PrivacyAttackScenario(
      id: id,
      sourceControlId: sourceId,
      schemaVersion: privacyAttackSchemaVersion,
      seed: seed,
      at: _baseAt,
      ownerId: _owner,
      intendedRecipientId: _recipient,
      attemptedRecipientId: _recipient,
      family: family,
      targetSurface: 'relationshipNotification',
      mutation: _mutation(
        id: id,
        family: family,
        sourceControlId: sourceId,
        dimensions: <String>{safeControl ? 'control' : 'notificationPrivacy'},
      ),
      containmentContract: safeControl
          ? PrivacyContainmentContract.emitNotification
          : PrivacyContainmentContract.redactOrSuppressNotification,
      riskTags: const <String>{'notificationPrivacy', 'phase10Reuse'},
      payload: <String, Object?>{
        'category': 'relationship.context',
        'categoryLabel': 'relationship',
        'detail': 'private detail',
        'kind': kind,
        'mode': mode,
        'deviceUnlocked': deviceUnlocked,
        'relationshipGrants': grants ?? <Object?>[notifyGrant],
      },
      safeControl: safeControl,
      adversarial: !safeControl,
    );
  }

  return <PrivacyAttackScenario>[
    build(
      id: 'control-notification-generic',
      mode: 'generic',
      deviceUnlocked: false,
      kind: 'relationship',
      safeControl: true,
    ),
    build(
      id: 'control-notification-category-only',
      mode: 'categoryOnly',
      deviceUnlocked: true,
      kind: 'relationship',
      safeControl: true,
    ),
    build(
      id: 'control-notification-detailed-unlocked',
      mode: 'detailedWhenUnlocked',
      deviceUnlocked: true,
      kind: 'relationship',
      safeControl: true,
    ),
    build(
      id: 'attack-notification-detailed-locked',
      mode: 'detailedWhenUnlocked',
      deviceUnlocked: false,
      kind: 'relationship',
      safeControl: false,
    ),
    build(
      id: 'attack-notification-missing-playful',
      mode: 'detailedWhenUnlocked',
      deviceUnlocked: true,
      kind: 'playful',
      safeControl: false,
    ),
    build(
      id: 'attack-notification-missing-intimacy',
      mode: 'detailedWhenUnlocked',
      deviceUnlocked: true,
      kind: 'intimacy',
      safeControl: false,
    ),
  ];
}

class _RegistryKeyRotator implements RecipientKeyRotator {
  _RegistryKeyRotator(this.registry);

  final RecipientKeyRegistry registry;

  @override
  Future<String> rotate({
    required String ownerId,
    required String recipientId,
    required DateTime at,
  }) async {
    final active =
        registry.activeFor(ownerId: ownerId, recipientId: recipientId);
    final nextVersion = (active?.version ?? 0) + 1;
    final nextId = 'rotated-$ownerId-$recipientId-v$nextVersion';
    registry.rotate(
      ownerId: ownerId,
      recipientId: recipientId,
      newKeyEnvelopeId: nextId,
      at: at,
    );
    return nextId;
  }
}

Future<PrivacyAttackObservation> _observeRevocationKeyState(
  PrivacyAttackScenario scenario,
) async {
  final grant = _permissionGrants(<Object?>[scenario.payload['grant']]).single;
  final initialKey = _requiredString(scenario.payload, 'initialKeyEnvelopeId');
  final registry = RecipientKeyRegistry(
    initial: <RecipientKeyState>[
      RecipientKeyState(
        ownerId: grant.ownerId,
        recipientId: grant.recipientId,
        keyEnvelopeId: initialKey,
        version: 1,
        createdAt: scenario.at.subtract(const Duration(days: 1)),
      ),
    ],
  );
  final rotator = _RegistryKeyRotator(registry);
  final phase8 = ProductionHardSafetyObserver().observe(
    HardSafetyCase(
      id: '${scenario.id}-phase8-revocation',
      invariantId: HardSafetyInvariantId.permissionRevocationBoundary,
      observedAt: scenario.at,
      seed: scenario.seed,
      input: <String, Object?>{
        'ownerId': grant.ownerId,
        'recipientId': grant.recipientId,
        'category': grant.scope.categories.first,
        'createdAt': grant.createdAt.toUtc().toIso8601String(),
        'revokedAt': scenario.at.toIso8601String(),
        'requestAt': scenario.at.toIso8601String(),
      },
    ),
  );
  if (phase8.facts['allowed'] != false ||
      phase8.facts['atOrAfterRevocation'] != true) {
    throw StateError('Phase 8 revocation boundary cross-check failed');
  }
  final effect = const PermissionEvaluator().revocationEffect(grant);
  final result = await const SharingRevocationCoordinator().revoke(
    grant: grant,
    keyRotator: rotator,
    at: scenario.at,
  );
  final active = registry.activeFor(
    ownerId: grant.ownerId,
    recipientId: grant.recipientId,
  );
  return PrivacyAttackObservation(
    keyRotated: result.newKeyEnvelopeId.isNotEmpty &&
        active?.keyEnvelopeId != initialKey,
    notificationsStopped: result.notificationsStopped,
    exportsInvalidated: effect.invalidateExports,
    staleKeyActive: active?.keyEnvelopeId == initialKey,
    reason: 'revocation_complete',
  );
}

AesGcmAuthenticatedCipher _fixtureCipher() => AesGcmAuthenticatedCipher(
      keyResolver: (keyEnvelopeId) async {
        final source = utf8.encode(keyEnvelopeId);
        if (source.isEmpty) throw ArgumentError('keyEnvelopeId is required');
        return List<int>.generate(
          32,
          (index) => (source[index % source.length] + index * 37) & 0xff,
        );
      },
    );

Future<PrivacyAttackObservation> _observeRelayTransport(
  PrivacyAttackScenario scenario,
) async {
  final transport = SharingTransport(_fixtureCipher());
  final keyEnvelopeId = _requiredString(scenario.payload, 'keyEnvelopeId');
  final mode = _requiredString(scenario.payload, 'mode');
  final envelope = await transport.encryptForRecipient(
    messageId: 'message-${scenario.sourceControlId}',
    ownerId: scenario.ownerId,
    recipientId: scenario.intendedRecipientId,
    keyEnvelopeId: keyEnvelopeId,
    plaintext: utf8.encode('deterministic-private-payload'),
    createdAt: scenario.at,
  );

  if (mode == 'safe' || mode == 'wrongRecipient') {
    try {
      await transport.decryptForRecipient(
        envelope: envelope,
        recipientId: scenario.attemptedRecipientId,
      );
      return const PrivacyAttackObservation(
        relayDecryptAccepted: true,
        reason: 'relay_decrypt_accepted',
      );
    } catch (_) {
      return const PrivacyAttackObservation(
        relayDecryptAccepted: false,
        reason: 'relay_decrypt_rejected',
      );
    }
  }

  final original = envelope.ciphertext;
  late final CiphertextEnvelope tamperedCiphertext;
  if (mode == 'tamperAssociatedData') {
    final associatedData =
        List<int>.of(original.associatedData ?? const <int>[]);
    if (associatedData.isEmpty) throw StateError('associated data missing');
    associatedData[0] ^= 0x01;
    tamperedCiphertext = CiphertextEnvelope(
      algorithm: original.algorithm,
      keyEnvelopeId: original.keyEnvelopeId,
      nonce: original.nonce,
      ciphertext: original.ciphertext,
      authenticationTag: original.authenticationTag,
      associatedData: associatedData,
    );
  } else if (mode == 'tamperCiphertext') {
    final ciphertext = List<int>.of(original.ciphertext);
    if (ciphertext.isEmpty) throw StateError('ciphertext missing');
    ciphertext[0] ^= 0x01;
    tamperedCiphertext = CiphertextEnvelope(
      algorithm: original.algorithm,
      keyEnvelopeId: original.keyEnvelopeId,
      nonce: original.nonce,
      ciphertext: ciphertext,
      authenticationTag: original.authenticationTag,
      associatedData: original.associatedData,
    );
  } else {
    throw ArgumentError('Unsupported relay mode: $mode');
  }
  final tampered = OpaqueRelayEnvelope(
    messageId: envelope.messageId,
    ownerId: envelope.ownerId,
    recipientId: envelope.recipientId,
    keyEnvelopeId: envelope.keyEnvelopeId,
    ciphertext: tamperedCiphertext,
    createdAt: envelope.createdAt,
    kind: envelope.kind,
  );
  try {
    await transport.decryptForRecipient(
      envelope: tampered,
      recipientId: scenario.attemptedRecipientId,
    );
    return const PrivacyAttackObservation(
      relayIntegrityAccepted: true,
      reason: 'relay_integrity_accepted',
    );
  } catch (_) {
    return const PrivacyAttackObservation(
      relayIntegrityAccepted: false,
      reason: 'relay_integrity_rejected',
    );
  }
}

List<PrivacyAttackScenario> _revocationKeyScenarios(int seed) {
  const family = PrivacyAttackFamily.revocationAndKeyReplay;
  final revocationGrant = Map<String, Object?>.from(
    _grant(id: 'grant-revocation-key', action: 'view'),
  )..['actions'] = <String>['view', 'notify', 'export'];

  PrivacyAttackScenario revokeCase({
    required String id,
    required PrivacyContainmentContract contract,
    required bool safeControl,
  }) {
    final sourceId = safeControl ? id : 'control-revocation-key-rotation';
    return PrivacyAttackScenario(
      id: id,
      sourceControlId: sourceId,
      schemaVersion: privacyAttackSchemaVersion,
      seed: seed,
      at: _baseAt,
      ownerId: _owner,
      intendedRecipientId: _recipient,
      attemptedRecipientId: _recipient,
      family: family,
      targetSurface: 'revocationKeyState',
      mutation: _mutation(
        id: id,
        family: family,
        sourceControlId: sourceId,
        dimensions: <String>{safeControl ? 'control' : 'staleKey'},
      ),
      containmentContract: contract,
      riskTags: const <String>{
        'revocation',
        'recipientKey',
        'phase8Reuse',
        'phase9Reuse'
      },
      payload: <String, Object?>{
        'grant': revocationGrant,
        'initialKeyEnvelopeId': 'recipient-key-v1',
      },
      safeControl: safeControl,
      adversarial: !safeControl,
    );
  }

  final revokedGrant = _grant(
    id: 'grant-revoked-reuse',
    action: 'view',
    revokedAt: _baseAt,
  );
  final revokedReuse = PrivacyAttackScenario(
    id: 'attack-revoked-grant-reuse',
    sourceControlId: 'control-revocation-key-rotation',
    schemaVersion: privacyAttackSchemaVersion,
    seed: seed,
    at: _baseAt,
    ownerId: _owner,
    intendedRecipientId: _recipient,
    attemptedRecipientId: _recipient,
    family: family,
    targetSurface: 'genericPermission',
    mutation: _mutation(
      id: 'attack-revoked-grant-reuse',
      family: family,
      sourceControlId: 'control-revocation-key-rotation',
      dimensions: const <String>{'revokedGrant'},
    ),
    containmentContract: PrivacyContainmentContract.denyAuthority,
    riskTags: const <String>{'revocation', 'phase9Reuse'},
    payload: <String, Object?>{
      'request': <String, Object?>{
        'action': 'view',
        'category': 'cycle',
      },
      'grants': <Object?>[revokedGrant],
    },
    adversarial: true,
  );

  return <PrivacyAttackScenario>[
    revokeCase(
      id: 'control-revocation-key-rotation',
      contract: PrivacyContainmentContract.requireKeyRotation,
      safeControl: true,
    ),
    revokeCase(
      id: 'attack-stale-key-replay',
      contract: PrivacyContainmentContract.rejectStaleKey,
      safeControl: false,
    ),
    revokedReuse,
  ];
}

List<PrivacyAttackScenario> _relayScenarios(int seed) {
  const family = PrivacyAttackFamily.relayRecipientBinding;

  PrivacyAttackScenario build({
    required String id,
    required String mode,
    required PrivacyContainmentContract contract,
    required bool safeControl,
    String attemptedRecipientId = _recipient,
    Set<String> dimensions = const <String>{'control'},
  }) {
    final sourceId = safeControl ? id : 'control-relay-correct-recipient';
    return PrivacyAttackScenario(
      id: id,
      sourceControlId: sourceId,
      schemaVersion: privacyAttackSchemaVersion,
      seed: seed,
      at: _baseAt,
      ownerId: _owner,
      intendedRecipientId: _recipient,
      attemptedRecipientId: attemptedRecipientId,
      family: family,
      targetSurface: 'relayTransport',
      mutation: _mutation(
        id: id,
        family: family,
        sourceControlId: sourceId,
        dimensions: dimensions,
      ),
      containmentContract: contract,
      riskTags: const <String>{'relay', 'crypto'},
      payload: <String, Object?>{
        'mode': mode,
        'keyEnvelopeId': 'relay-key-v1',
      },
      safeControl: safeControl,
      adversarial: !safeControl,
    );
  }

  return <PrivacyAttackScenario>[
    build(
      id: 'control-relay-correct-recipient',
      mode: 'safe',
      contract: PrivacyContainmentContract.allowRelayDecrypt,
      safeControl: true,
    ),
    build(
      id: 'attack-relay-wrong-recipient',
      mode: 'wrongRecipient',
      contract: PrivacyContainmentContract.rejectRelayDecrypt,
      safeControl: false,
      attemptedRecipientId: _otherRecipient,
      dimensions: const <String>{'recipient'},
    ),
    build(
      id: 'attack-relay-associated-data-tamper',
      mode: 'tamperAssociatedData',
      contract: PrivacyContainmentContract.rejectRelayIntegrityTamper,
      safeControl: false,
      dimensions: const <String>{'associatedData'},
    ),
    build(
      id: 'attack-relay-ciphertext-tamper',
      mode: 'tamperCiphertext',
      contract: PrivacyContainmentContract.rejectRelayIntegrityTamper,
      safeControl: false,
      dimensions: const <String>{'ciphertext'},
    ),
  ];
}

Future<PrivacyAttackReport> runProductionPrivacyAttackSmoke(int seed) =>
    const PrivacyAttackSuite().evaluate(
      seed: seed,
      scenarios: buildCanonicalPrivacyAttackScenarios(seed),
      observer: const ProductionPrivacyAttackObserver(),
      requireMandatoryCoverage: true,
    );
