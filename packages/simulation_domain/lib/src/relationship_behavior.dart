import 'dart:convert';

import 'package:cycle_sharing/cycle_sharing.dart';

import 'hard_safety.dart';
import 'models.dart';

const int relationshipBehaviorSchemaVersion = 1;

enum RelationshipBehaviorScenarioFamily {
  signalProjection,
  situation,
  memoryContext,
  novelty,
  partnerHome,
  notification,
  playful,
  intimacy,
  preset,
}

class RelationshipBehaviorScenario {
  RelationshipBehaviorScenario({
    required this.id,
    required this.schemaVersion,
    required this.seed,
    required this.at,
    required this.ownerId,
    required this.recipientId,
    required this.family,
    required Map<String, Object?> expectedFacts,
    required Set<String> riskTags,
    Map<String, Object?> payload = const <String, Object?>{},
    this.safeControl = false,
    this.adversarial = false,
  })  : expectedFacts = Map<String, Object?>.unmodifiable(expectedFacts),
        riskTags = Set<String>.unmodifiable(riskTags),
        payload = Map<String, Object?>.unmodifiable(payload) {
    if (schemaVersion != relationshipBehaviorSchemaVersion) {
      throw ArgumentError('Unsupported relationship-behavior schema version');
    }
    _requireText(id, 'id');
    _requireText(ownerId, 'ownerId');
    _requireText(recipientId, 'recipientId');
    if (ownerId == recipientId) {
      throw ArgumentError('relationship actors must differ');
    }
    if (!at.isUtc) throw ArgumentError('at must be UTC');
    for (final key in expectedFacts.keys) {
      _requireText(key, 'expectedFacts key');
    }
    for (final tag in riskTags) {
      _requireText(tag, 'riskTag');
    }
  }

  final String id;
  final int schemaVersion;
  final int seed;
  final DateTime at;
  final String ownerId;
  final String recipientId;
  final RelationshipBehaviorScenarioFamily family;
  final Map<String, Object?> expectedFacts;
  final Set<String> riskTags;
  final Map<String, Object?> payload;
  final bool safeControl;
  final bool adversarial;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'schemaVersion': schemaVersion,
        'seed': seed,
        'at': at.toIso8601String(),
        'ownerId': ownerId,
        'recipientId': recipientId,
        'family': family.name,
        'expectedFacts': _canonicalize(expectedFacts),
        'riskTags': riskTags.toList()..sort(),
        'payload': _canonicalize(payload),
        'safeControl': safeControl,
        'adversarial': adversarial,
      };

  factory RelationshipBehaviorScenario.fromJson(Map<String, Object?> json) {
    final familyName = json['family'];
    if (familyName is! String) throw ArgumentError('family is required');
    final family = RelationshipBehaviorScenarioFamily.values.firstWhere(
      (item) => item.name == familyName,
      orElse: () => throw ArgumentError('Unsupported family: $familyName'),
    );
    return RelationshipBehaviorScenario(
      id: json['id'] as String,
      schemaVersion: json['schemaVersion'] as int,
      seed: json['seed'] as int,
      at: _parseUtc(json['at'], 'at'),
      ownerId: json['ownerId'] as String,
      recipientId: json['recipientId'] as String,
      family: family,
      expectedFacts: _objectMap(json['expectedFacts']),
      riskTags: _stringSet(json['riskTags']),
      payload: _objectMap(json['payload']),
      safeControl: json['safeControl'] as bool? ?? false,
      adversarial: json['adversarial'] as bool? ?? false,
    );
  }
}

class RelationshipBehaviorObservation {
  const RelationshipBehaviorObservation(
      {this.facts = const <String, Object?>{}});
  final Map<String, Object?> facts;
  Map<String, Object?> toJson() =>
      <String, Object?>{'facts': _canonicalize(facts)};
}

abstract class RelationshipBehaviorObserver {
  const RelationshipBehaviorObserver();
  RelationshipBehaviorObservation observe(
      RelationshipBehaviorScenario scenario);
}

class RelationshipBehaviorResult {
  RelationshipBehaviorResult({
    required this.scenarioId,
    required this.family,
    required this.passed,
    required this.reasonCode,
    required this.severity,
    required this.evaluatedAt,
    Map<String, Object?> evidence = const <String, Object?>{},
  }) : evidence = Map<String, Object?>.unmodifiable(evidence) {
    _requireText(scenarioId, 'scenarioId');
    _requireText(reasonCode, 'reasonCode');
    if (!evaluatedAt.isUtc) throw ArgumentError('evaluatedAt must be UTC');
  }

  final String scenarioId;
  final RelationshipBehaviorScenarioFamily family;
  final bool passed;
  final String reasonCode;
  final InvariantSeverity severity;
  final DateTime evaluatedAt;
  final Map<String, Object?> evidence;

  Map<String, Object?> toJson() => <String, Object?>{
        'scenarioId': scenarioId,
        'family': family.name,
        'passed': passed,
        'reasonCode': reasonCode,
        'severity': severity.name,
        'evaluatedAt': evaluatedAt.toIso8601String(),
        'evidence': _canonicalize(evidence),
      };

  factory RelationshipBehaviorResult.fromJson(Map<String, Object?> json) =>
      RelationshipBehaviorResult(
        scenarioId: json['scenarioId'] as String,
        family: RelationshipBehaviorScenarioFamily.values.firstWhere(
          (item) => item.name == json['family'],
        ),
        passed: json['passed'] as bool,
        reasonCode: json['reasonCode'] as String,
        severity: InvariantSeverity.values.firstWhere(
          (item) => item.name == json['severity'],
        ),
        evaluatedAt: _parseUtc(json['evaluatedAt'], 'evaluatedAt'),
        evidence: _objectMap(json['evidence']),
      );
}

class RelationshipBehaviorCoverage {
  const RelationshipBehaviorCoverage({
    this.configuredScenarios = 0,
    this.evaluatedScenarios = 0,
    this.passedScenarios = 0,
    this.failedScenarios = 0,
    this.malformedInputFailures = 0,
    this.safeControls = 0,
    this.adversarialScenarios = 0,
    this.families = const <String, int>{},
    this.riskTags = const <String, int>{},
    this.phase8ReuseCount = 0,
    this.phase9ReuseCount = 0,
  });

  const RelationshipBehaviorCoverage.empty() : this();

  final int configuredScenarios;
  final int evaluatedScenarios;
  final int passedScenarios;
  final int failedScenarios;
  final int malformedInputFailures;
  final int safeControls;
  final int adversarialScenarios;
  final Map<String, int> families;
  final Map<String, int> riskTags;
  final int phase8ReuseCount;
  final int phase9ReuseCount;

  factory RelationshipBehaviorCoverage.fromRun({
    required Iterable<RelationshipBehaviorScenario> scenarios,
    required Iterable<RelationshipBehaviorResult> results,
  }) {
    final scenarioList = scenarios.toList(growable: false);
    final resultList = results.toList(growable: false);
    final families = <String, int>{};
    final tags = <String, int>{};
    for (final scenario in scenarioList) {
      families.update(scenario.family.name, (value) => value + 1,
          ifAbsent: () => 1);
      for (final tag in scenario.riskTags) {
        tags.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return RelationshipBehaviorCoverage(
      configuredScenarios: scenarioList.length,
      evaluatedScenarios: resultList.length,
      passedScenarios: resultList.where((item) => item.passed).length,
      failedScenarios: resultList.where((item) => !item.passed).length,
      malformedInputFailures: resultList
          .where((item) => item.reasonCode == 'malformed_input')
          .length,
      safeControls: scenarioList.where((item) => item.safeControl).length,
      adversarialScenarios:
          scenarioList.where((item) => item.adversarial).length,
      families: Map<String, int>.unmodifiable(families),
      riskTags: Map<String, int>.unmodifiable(tags),
      phase8ReuseCount: tags['phase8Reuse'] ?? 0,
      phase9ReuseCount: tags['phase9Reuse'] ?? 0,
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
        'phase8ReuseCount': phase8ReuseCount,
        'phase9ReuseCount': phase9ReuseCount,
      };

  factory RelationshipBehaviorCoverage.fromJson(Map<String, Object?> json) =>
      RelationshipBehaviorCoverage(
        configuredScenarios: json['configuredScenarios'] as int? ?? 0,
        evaluatedScenarios: json['evaluatedScenarios'] as int? ?? 0,
        passedScenarios: json['passedScenarios'] as int? ?? 0,
        failedScenarios: json['failedScenarios'] as int? ?? 0,
        malformedInputFailures: json['malformedInputFailures'] as int? ?? 0,
        safeControls: json['safeControls'] as int? ?? 0,
        adversarialScenarios: json['adversarialScenarios'] as int? ?? 0,
        families: _intMap(json['families']),
        riskTags: _intMap(json['riskTags']),
        phase8ReuseCount: json['phase8ReuseCount'] as int? ?? 0,
        phase9ReuseCount: json['phase9ReuseCount'] as int? ?? 0,
      );
}

class RelationshipBehaviorReport {
  RelationshipBehaviorReport({
    required this.seed,
    required Iterable<RelationshipBehaviorResult> results,
    required this.coverage,
  }) : results = List<RelationshipBehaviorResult>.unmodifiable(
          List<RelationshipBehaviorResult>.from(results)
            ..sort((a, b) => a.scenarioId.compareTo(b.scenarioId)),
        );

  final int seed;
  final List<RelationshipBehaviorResult> results;
  final RelationshipBehaviorCoverage coverage;
  bool get syntheticEvidenceOnly => true;
  bool get passed =>
      results.every((item) => item.passed) && coverage.failedScenarios == 0;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': relationshipBehaviorSchemaVersion,
        'seed': seed,
        'syntheticEvidenceOnly': true,
        'passed': passed,
        'coverage': coverage.toJson(),
        'results': results.map((item) => item.toJson()).toList(growable: false),
      };

  String toNormalizedJson() => jsonEncode(_canonicalize(toJson()));

  factory RelationshipBehaviorReport.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != relationshipBehaviorSchemaVersion) {
      throw ArgumentError('Unsupported relationship-behavior report schema');
    }
    final rawResults = json['results'];
    if (rawResults is! List) throw ArgumentError('results must be a list');
    return RelationshipBehaviorReport(
      seed: json['seed'] as int,
      results: rawResults
          .map((item) => RelationshipBehaviorResult.fromJson(_objectMap(item)))
          .toList(growable: false),
      coverage: RelationshipBehaviorCoverage.fromJson(
        _objectMap(json['coverage']),
      ),
    );
  }
}

class RelationshipBehaviorSuite {
  const RelationshipBehaviorSuite({required this.observer});
  final RelationshipBehaviorObserver observer;

  RelationshipBehaviorResult evaluate(RelationshipBehaviorScenario scenario) {
    final observation = observer.observe(scenario);
    final passed = _matchesExpected(scenario.expectedFacts, observation.facts);
    return RelationshipBehaviorResult(
      scenarioId: scenario.id,
      family: scenario.family,
      passed: passed,
      reasonCode: passed ? 'contract_satisfied' : 'contract_mismatch',
      severity: _severityFor(scenario.riskTags),
      evaluatedAt: scenario.at,
      evidence: observation.toJson(),
    );
  }

  RelationshipBehaviorReport run({
    required int seed,
    required Iterable<RelationshipBehaviorScenario> scenarios,
    bool requireMandatoryCoverage = false,
  }) {
    final ordered = List<RelationshipBehaviorScenario>.from(scenarios)
      ..sort((a, b) => a.id.compareTo(b.id));
    final results = <RelationshipBehaviorResult>[];
    for (final scenario in ordered) {
      if (scenario.seed != seed) {
        results.add(_malformed(scenario, 'seed_mismatch'));
        continue;
      }
      try {
        results.add(evaluate(scenario));
      } on Object catch (error) {
        results.add(_malformed(scenario, error.runtimeType.toString()));
      }
    }
    final coverage = RelationshipBehaviorCoverage.fromRun(
      scenarios: ordered,
      results: results,
    );
    if (requireMandatoryCoverage) {
      final gaps = _mandatoryCoverageGaps(coverage);
      if (gaps.isNotEmpty) {
        results.add(
          RelationshipBehaviorResult(
            scenarioId: 'coverage.gap',
            family: RelationshipBehaviorScenarioFamily.signalProjection,
            passed: false,
            reasonCode: 'coverage_gap',
            severity: InvariantSeverity.s2,
            evaluatedAt:
                ordered.isEmpty ? DateTime.utc(1970, 1, 1) : ordered.first.at,
            evidence: <String, Object?>{'missing': gaps},
          ),
        );
      }
    }
    return RelationshipBehaviorReport(
      seed: seed,
      results: results,
      coverage: coverage,
    );
  }

  RelationshipBehaviorResult _malformed(
    RelationshipBehaviorScenario scenario,
    String errorType,
  ) =>
      RelationshipBehaviorResult(
        scenarioId: scenario.id,
        family: scenario.family,
        passed: false,
        reasonCode: 'malformed_input',
        severity: _severityFor(scenario.riskTags),
        evaluatedAt: scenario.at,
        evidence: <String, Object?>{'errorType': errorType},
      );
}

InvariantSeverity _severityFor(Set<String> tags) {
  const hard = <String>{
    'scope',
    'permission',
    'visibility',
    'notificationPrivacy',
    'consent',
    'clinicalTruth',
  };
  return tags.any(hard.contains) ? InvariantSeverity.s4 : InvariantSeverity.s2;
}

bool _matchesExpected(Object? expected, Object? actual) {
  if (expected is Map) {
    if (actual is! Map) return false;
    for (final entry in expected.entries) {
      if (!actual.containsKey(entry.key)) return false;
      if (!_matchesExpected(entry.value, actual[entry.key])) return false;
    }
    return true;
  }
  if (expected is List) {
    if (actual is! List || actual.length != expected.length) return false;
    for (var index = 0; index < expected.length; index++) {
      if (!_matchesExpected(expected[index], actual[index])) return false;
    }
    return true;
  }
  return expected == actual;
}

void _requireText(String value, String field) {
  if (value.trim().isEmpty) throw ArgumentError('$field must not be blank');
}

DateTime _parseUtc(Object? value, String field) {
  if (value is! String) throw ArgumentError('$field is required');
  final parsed = DateTime.parse(value);
  if (!parsed.isUtc) throw ArgumentError('$field must be UTC');
  return parsed;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) throw ArgumentError('Expected an object');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

Set<String> _stringSet(Object? value) {
  if (value is! List) throw ArgumentError('Expected a string list');
  return value.map((item) {
    if (item is! String) throw ArgumentError('Expected a string list');
    return item;
  }).toSet();
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return const <String, int>{};
  return value.map((key, item) => MapEntry(key.toString(), item as int));
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Set) {
    final values = value.map(_canonicalize).toList()
      ..sort((a, b) => a.toString().compareTo(b.toString()));
    return values;
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}

class ProductionRelationshipBehaviorObserver
    extends RelationshipBehaviorObserver {
  const ProductionRelationshipBehaviorObserver({
    this.signalEngine = const RelationshipSignalEngine(),
    this.signalProjector = const PartnerSignalProjector(),
    this.situationEngine = const RelationshipSituationEngine(),
    this.memoryEngine = const CoupleMemoryEngine(),
    this.contextEngine = const CoupleContextEngine(),
    this.noveltyEngine = const NoveltyEngine(),
    this.homeOrchestrator = const RelationshipHomeOrchestrator(),
    this.partnerCoordinator = const PartnerExperienceCoordinator(),
    this.notificationPipeline = const RelationshipNotificationPipeline(),
    this.playfulEngine = const PlayfulEngine(),
    this.intimacyEngine = const IntimacyEngine(),
    this.presetExpander = const RelationshipPresetExpander(),
  });

  final RelationshipSignalEngine signalEngine;
  final PartnerSignalProjector signalProjector;
  final RelationshipSituationEngine situationEngine;
  final CoupleMemoryEngine memoryEngine;
  final CoupleContextEngine contextEngine;
  final NoveltyEngine noveltyEngine;
  final RelationshipHomeOrchestrator homeOrchestrator;
  final PartnerExperienceCoordinator partnerCoordinator;
  final RelationshipNotificationPipeline notificationPipeline;
  final PlayfulEngine playfulEngine;
  final IntimacyEngine intimacyEngine;
  final RelationshipPresetExpander presetExpander;

  @override
  RelationshipBehaviorObservation observe(
      RelationshipBehaviorScenario scenario) {
    return switch (scenario.family) {
      RelationshipBehaviorScenarioFamily.signalProjection =>
        _observeSignals(scenario),
      RelationshipBehaviorScenarioFamily.situation =>
        _observeSituation(scenario),
      RelationshipBehaviorScenarioFamily.memoryContext =>
        _observeMemoryContext(scenario),
      RelationshipBehaviorScenarioFamily.novelty => _observeNovelty(scenario),
      RelationshipBehaviorScenarioFamily.partnerHome =>
        _observePartnerHome(scenario),
      RelationshipBehaviorScenarioFamily.notification =>
        _observeNotification(scenario),
      RelationshipBehaviorScenarioFamily.playful => _observePlayful(scenario),
      RelationshipBehaviorScenarioFamily.intimacy => _observeIntimacy(scenario),
      RelationshipBehaviorScenarioFamily.preset => _observePreset(scenario),
    };
  }

  RelationshipBehaviorObservation _observeSignals(
      RelationshipBehaviorScenario scenario) {
    final signals = _relationshipSignals(scenario.payload['signals'], scenario);
    final grants = _relationshipGrants(scenario.payload['grants']);
    final selected = signalEngine.selectActive(
      ownerId: scenario.ownerId,
      recipientId: scenario.recipientId,
      at: scenario.at,
      signals: signals,
    );
    final projected = signalProjector.project(
      ownerId: scenario.ownerId,
      recipientId: scenario.recipientId,
      at: scenario.at,
      signals: signals,
      grants: grants,
    );
    return RelationshipBehaviorObservation(
      facts: <String, Object?>{
        'selectedSignalIds':
            selected.map((item) => item.id).toList(growable: false),
        'projectedSignalIds':
            projected.map((item) => item.id).toList(growable: false),
        'projectedVisibilities': projected
            .map((item) => item.visibility.name)
            .toList(growable: false),
      },
    );
  }

  RelationshipBehaviorObservation _observeSituation(
      RelationshipBehaviorScenario scenario) {
    final signals = _roomSignals(scenario.payload['roomSignals'], scenario);
    final grants = _relationshipGrants(scenario.payload['grants']);
    final room = situationEngine.readTheRoom(
      ownerId: scenario.ownerId,
      partnerId: scenario.recipientId,
      at: scenario.at,
      signals: signals,
      grants: grants,
    );
    final weather = situationEngine.weather(
      ownerId: scenario.ownerId,
      partnerId: scenario.recipientId,
      at: scenario.at,
      signals: signals,
      grants: grants,
    );
    final micro = situationEngine.chooseMicroMoment(
      userInteractedRecently:
          scenario.payload['userInteractedRecently'] == true,
      candidates: _microMoments(scenario.payload['microMoments']),
    );
    return RelationshipBehaviorObservation(
      facts: <String, Object?>{
        'roomSignalId': room?.signalId,
        'roomAction': room?.action.name,
        'weather': weather.kind.name,
        'weatherSignalIds': weather.basedOnSignalIds,
        'microMomentSurfaced': micro.shouldSurface,
        'microMomentReason': micro.reason,
        'microMomentId': micro.candidate?.id,
      },
    );
  }

  RelationshipBehaviorObservation _observeMemoryContext(
      RelationshipBehaviorScenario scenario) {
    final operation = scenario.payload['operation'] as String? ?? 'memory';
    final grants = _relationshipGrants(scenario.payload['grants']);
    if (operation == 'memory') {
      final manual = memoryEngine.buildPartnerManual(
        ownerId: scenario.ownerId,
        partnerId: scenario.recipientId,
        capability:
            _relationshipCapability(scenario.payload['capability'] ?? 'view'),
        at: scenario.at,
        items: _memories(scenario.payload['memories'], scenario),
        grants: grants,
      );
      return RelationshipBehaviorObservation(
        facts: <String, Object?>{
          'memoryIds':
              manual.entries.map((item) => item.id).toList(growable: false),
          'memoryVisibilities': manual.entries
              .map((item) => item.visibility.name)
              .toList(growable: false),
          'memoryRawValues':
              manual.entries.map((item) => item.value).toList(growable: false),
        },
      );
    }
    if (operation == 'context') {
      final context = contextEngine.build<Object?>(
        ownerId: scenario.ownerId,
        recipientId: scenario.recipientId,
        capability:
            _relationshipCapability(scenario.payload['capability'] ?? 'view'),
        at: scenario.at,
        entries: _contextEntries(scenario.payload['entries'], scenario),
        grants: grants,
      );
      return RelationshipBehaviorObservation(
        facts: <String, Object?>{
          'contextCategories': context.projections
              .map((item) => item.category)
              .toList(growable: false),
          'contextVisibilities': context.projections
              .map((item) => item.visibility.name)
              .toList(growable: false),
          'contextRawValues': context.projections
              .map((item) => item.value)
              .toList(growable: false),
        },
      );
    }
    throw ArgumentError('Unsupported memory/context operation: $operation');
  }

  RelationshipBehaviorObservation _observeNovelty(
      RelationshipBehaviorScenario scenario) {
    final suggestions = noveltyEngine.surpriseMeSafely(
      ownerId: scenario.ownerId,
      recipientId: scenario.recipientId,
      at: scenario.at,
      dna: _coupleDna(scenario.payload['dna'], scenario),
      candidates: _noveltyCandidates(scenario.payload['candidates']),
      history: _noveltyHistory(scenario.payload['history']),
      grants: _relationshipGrants(scenario.payload['grants']),
      limit: scenario.payload['limit'] as int? ?? 3,
    );
    return RelationshipBehaviorObservation(
      facts: <String, Object?>{
        'suggestionIds':
            suggestions.map((item) => item.candidateId).toList(growable: false),
        'suggestionScores':
            suggestions.map((item) => item.score).toList(growable: false),
        'suggestionReasonTags':
            suggestions.map((item) => item.reasonTags).toList(growable: false),
      },
    );
  }

  RelationshipBehaviorObservation _observePartnerHome(
      RelationshipBehaviorScenario scenario) {
    if (scenario.payload['forceSameActorScope'] == true) {
      try {
        partnerCoordinator.build(
          PartnerExperienceInput(
            ownerId: scenario.ownerId,
            partnerId: scenario.ownerId,
            at: scenario.at,
            grants: const <RelationshipCategoryGrant>[],
          ),
        );
      } on RelationshipPolicyException {
        return const RelationshipBehaviorObservation(
          facts: <String, Object?>{'homeBuildFailedClosed': true},
        );
      }
      return const RelationshipBehaviorObservation(
        facts: <String, Object?>{'homeBuildFailedClosed': false},
      );
    }
    final home = partnerCoordinator.build(
      PartnerExperienceInput(
        ownerId: scenario.ownerId,
        partnerId: scenario.recipientId,
        at: scenario.at,
        grants: _relationshipGrants(scenario.payload['grants']),
        roomSignals: _roomSignals(scenario.payload['roomSignals'], scenario),
        microMoments: _microMoments(scenario.payload['microMoments']),
        userInteractedRecently:
            scenario.payload['userInteractedRecently'] == true,
        memories: _memories(scenario.payload['memories'], scenario),
        sharedHealthEntries:
            _contextEntries(scenario.payload['sharedHealthEntries'], scenario),
        coupleDna: scenario.payload['dna'] == null
            ? null
            : _coupleDna(scenario.payload['dna'], scenario),
        noveltyCandidates: _noveltyCandidates(scenario.payload['candidates']),
        noveltyHistory: _noveltyHistory(scenario.payload['history']),
      ),
    );
    return RelationshipBehaviorObservation(
      facts: <String, Object?>{
        'homeBuildFailedClosed': false,
        'homeCardIds':
            home.cards.map((item) => item.id).toList(growable: false),
        'homeTabs':
            home.cards.map((item) => item.tab.name).toList(growable: false),
        'homeKinds':
            home.cards.map((item) => item.kind.name).toList(growable: false),
        'homeRawValues':
            home.cards.map((item) => item.rawValue).toList(growable: false),
      },
    );
  }

  RelationshipBehaviorObservation _observeNotification(
      RelationshipBehaviorScenario scenario) {
    final request = RelationshipNotificationRequest(
      ownerId: scenario.ownerId,
      recipientId: scenario.recipientId,
      category: _requiredString(scenario.payload, 'category'),
      categoryLabel: _requiredString(scenario.payload, 'categoryLabel'),
      detail: _requiredString(scenario.payload, 'detail'),
      kind: _enumByName(
        RelationshipNotificationKind.values,
        scenario.payload['kind'],
        'notification.kind',
      ),
      at: scenario.at,
    );
    final notification = notificationPipeline.present(
      request: request,
      mode: _enumByName(
        NotificationPrivacyMode.values,
        scenario.payload['mode'],
        'notification.mode',
      ),
      deviceUnlocked: scenario.payload['deviceUnlocked'] == true,
      grants: _relationshipGrants(scenario.payload['grants']),
    );
    return RelationshipBehaviorObservation(
      facts: <String, Object?>{
        'notificationPresented': notification != null,
        'notificationRedacted': notification?.redacted,
        'notificationTitle': notification?.title,
        'notificationBody': notification?.body,
      },
    );
  }

  RelationshipBehaviorObservation _observePlayful(
      RelationshipBehaviorScenario scenario) {
    final truthText = scenario.payload['truthText'] as String?;
    final truthSeverity = scenario.payload['truthSeverity'] == null
        ? null
        : _enumByName(
            ClinicalTruthSeverity.values,
            scenario.payload['truthSeverity'],
            'playful.truthSeverity',
          );
    final truth = truthText == null
        ? null
        : ClinicalTruthLayer(
            id: '${scenario.id}-truth',
            text: truthText,
            severity: truthSeverity ?? ClinicalTruthSeverity.informational,
            createdAt: scenario.at,
          );
    final composition = playfulEngine.compose(
      ownerId: scenario.ownerId,
      recipientId: scenario.recipientId,
      category: _requiredString(scenario.payload, 'category'),
      at: scenario.at,
      companionText: scenario.payload['companionText'] as String? ?? '',
      preferences: PlayfulPresentationPreferences(
        enabled: scenario.payload['enabled'] != false,
        tone: scenario.payload['tone'] == null
            ? PlayfulTone.warm
            : _enumByName(
                PlayfulTone.values, scenario.payload['tone'], 'playful.tone'),
        allowInSensitive: scenario.payload['allowInSensitive'] == true,
        allowInSeriousClinical:
            scenario.payload['allowInSeriousClinical'] == true,
        allowInUrgent: scenario.payload['allowInUrgent'] == true,
      ),
      grants: _relationshipGrants(scenario.payload['grants']),
      clinicalTruth: truth,
      isSensitive: scenario.payload['isSensitive'] == true,
      isSeriousClinical: scenario.payload['isSeriousClinical'] == true,
    );
    bool? phase8TruthGatePassed;
    if (truth != null) {
      final safetyCase = HardSafetyCase(
        id: '${scenario.id}-phase8',
        invariantId: HardSafetyInvariantId.relationshipClinicalTruthPreserved,
        patientId: scenario.ownerId,
        observedAt: scenario.at,
        seed: scenario.seed,
        input: <String, Object?>{
          'ownerId': scenario.ownerId,
          'recipientId': scenario.recipientId,
          'category': _requiredString(scenario.payload, 'category'),
          'truthText': truth.text,
          'severity': truth.severity.name,
          'preferencesEnabled': false,
          'companionText': scenario.payload['companionText'] as String? ?? '',
        },
      );
      phase8TruthGatePassed = HardSafetySuite(
        observer: ProductionHardSafetyObserver(),
      ).run(seed: scenario.seed, cases: <HardSafetyCase>[safetyCase]).passed;
    }
    return RelationshipBehaviorObservation(
      facts: <String, Object?>{
        'playfulApplied': composition.playfulApplied,
        'layerKinds': composition.layers.map((item) => item.kind.name).toList(),
        'layerTexts': composition.layers.map((item) => item.text).toList(),
        'layerTones': composition.layers.map((item) => item.tone.name).toList(),
        'truthFirst': truth == null ||
            (composition.layers.isNotEmpty &&
                composition.layers.first.kind ==
                    PlayfulLayerKind.clinicalTruth &&
                composition.layers.first.text == truth.text),
        'phase8TruthGatePassed': phase8TruthGatePassed,
      },
    );
  }

  RelationshipBehaviorObservation _observeIntimacy(
      RelationshipBehaviorScenario scenario) {
    final decisions = intimacyEngine.evaluate(
      participantAId: scenario.ownerId,
      participantBId: scenario.recipientId,
      at: scenario.at,
      preferences: _intimacyPreferences(scenario.payload['preferences']),
      willingness: _intimacyWillingness(scenario.payload['willingness']),
      boundaries: _intimacyBoundaries(scenario.payload['boundaries']),
      grants: _relationshipGrants(scenario.payload['grants']),
    );
    return RelationshipBehaviorObservation(
      facts: <String, Object?>{
        'intimacyDecisionIds': decisions.map((item) => item.id).toList(),
        'intimacyDecisionKinds':
            decisions.map((item) => item.kind.name).toList(),
        'intimacyCreatedAt':
            decisions.map((item) => item.createdAt.toIso8601String()).toList(),
        'intimacyExpiresAt':
            decisions.map((item) => item.expiresAt.toIso8601String()).toList(),
      },
    );
  }

  RelationshipBehaviorObservation _observePreset(
      RelationshipBehaviorScenario scenario) {
    final preset = _enumByName(
      RelationshipSharingPreset.values,
      scenario.payload['preset'],
      'preset',
    );
    final categories = _stringListOrEmpty(scenario.payload['categories']);
    final expansion = presetExpander.expand(
      preset: preset,
      categories: categories,
    );
    final grants = presetExpander.grantsFromPreset(
      preset: preset,
      categories: categories,
      ownerId: scenario.ownerId,
      recipientId: scenario.recipientId,
      createdAt: scenario.at,
      version: scenario.payload['version'] as int? ?? 1,
    );
    final orderedCategories = expansion.capabilitiesByCategory.keys.toList()
      ..sort();
    final capabilities = <String, List<String>>{
      for (final category in orderedCategories)
        category: (expansion.capabilitiesByCategory[category]!
            .map((e) => e.name)
            .toList()
          ..sort()),
    };
    final visibility = <String, String>{
      for (final category in orderedCategories)
        category: expansion.visibilityByCategory[category]!.name,
    };
    bool? policyCheckAllowed;
    if (scenario.payload['policyCheckCategory'] != null &&
        scenario.payload['policyCheckCapability'] != null) {
      policyCheckAllowed = const RelationshipPermissionFirewall()
          .evaluate(
            request: RelationshipAccessRequest(
              ownerId: scenario.ownerId,
              recipientId: scenario.recipientId,
              category: scenario.payload['policyCheckCategory'] as String,
              capability: _relationshipCapability(
                scenario.payload['policyCheckCapability'],
              ),
              at: scenario.at,
            ),
            grants: grants,
          )
          .allowed;
    }
    return RelationshipBehaviorObservation(
      facts: <String, Object?>{
        'presetCategories': orderedCategories,
        'presetCapabilities': capabilities,
        'presetVisibility': visibility,
        'presetGrantIds': grants.map((item) => item.id).toList(),
        'policyCheckAllowed': policyCheckAllowed,
      },
    );
  }
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value == null) return const <Map<String, Object?>>[];
  if (value is! List) throw ArgumentError('Expected a list');
  return value.map(_objectMap).toList(growable: false);
}

T _enumByName<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is! String) throw ArgumentError('$field is required');
  return values.firstWhere(
    (item) => item.name == value,
    orElse: () => throw ArgumentError('Unsupported $field: $value'),
  );
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw ArgumentError('$key is required');
  }
  return value;
}

DateTime _requiredUtc(Map<String, Object?> map, String key) =>
    _parseUtc(_requiredString(map, key), key);

DateTime? _optionalUtc(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  return _parseUtc(value, key);
}

Set<String> _stringSetOrEmpty(Object? value) {
  if (value == null) return const <String>{};
  if (value is! List) throw ArgumentError('Expected a string list');
  return value.map((item) {
    if (item is! String) throw ArgumentError('Expected a string list');
    return item;
  }).toSet();
}

RelationshipCapability _relationshipCapability(Object? value) =>
    _enumByName(RelationshipCapability.values, value, 'relationshipCapability');

RelationshipVisibility _relationshipVisibility(Object? value) =>
    _enumByName(RelationshipVisibility.values, value, 'relationshipVisibility');

List<RelationshipCategoryGrant> _relationshipGrants(Object? value) =>
    _mapList(value).map((map) {
      final capabilities = _stringSetOrEmpty(map['capabilities'])
          .map(_relationshipCapability)
          .toSet();
      return RelationshipCategoryGrant(
        id: _requiredString(map, 'id'),
        ownerId: _requiredString(map, 'ownerId'),
        recipientId: _requiredString(map, 'recipientId'),
        category: _requiredString(map, 'category'),
        capabilities: capabilities,
        visibility: _relationshipVisibility(map['visibility']),
        createdAt: _requiredUtc(map, 'createdAt'),
        validUntil: _optionalUtc(map, 'validUntil'),
        revokedAt: _optionalUtc(map, 'revokedAt'),
        version: map['version'] as int? ?? 1,
      );
    }).toList(growable: false);

List<RelationshipSignal> _relationshipSignals(
  Object? value,
  RelationshipBehaviorScenario scenario,
) =>
    _mapList(value).map((map) {
      return RelationshipSignal(
        id: _requiredString(map, 'id'),
        ownerId: map['ownerId'] as String? ?? scenario.ownerId,
        recipientId: map['recipientId'] as String? ?? scenario.recipientId,
        kind: _enumByName(
            RelationshipSignalKind.values, map['kind'], 'signal.kind'),
        origin: _enumByName(
            RelationshipSignalOrigin.values, map['origin'], 'signal.origin'),
        createdAt: _requiredUtc(map, 'createdAt'),
        expiresAt: _optionalUtc(map, 'expiresAt'),
        revokedAt: _optionalUtc(map, 'revokedAt'),
        customKey: map['customKey'] as String?,
        partnerFacingText: map['partnerFacingText'] as String?,
        version: map['version'] as int? ?? 1,
      );
    }).toList(growable: false);

List<RoomSignal> _roomSignals(
  Object? value,
  RelationshipBehaviorScenario scenario,
) =>
    _mapList(value).map((map) {
      return RoomSignal(
        id: _requiredString(map, 'id'),
        ownerId: map['ownerId'] as String? ?? scenario.ownerId,
        partnerId: map['partnerId'] as String? ?? scenario.recipientId,
        kind: _enumByName(RoomSignalKind.values, map['kind'], 'room.kind'),
        createdAt: _requiredUtc(map, 'createdAt'),
        expiresAt: _optionalUtc(map, 'expiresAt'),
        revokedAt: _optionalUtc(map, 'revokedAt'),
        priority: map['priority'] as int? ?? 0,
      );
    }).toList(growable: false);

List<MicroMomentCandidate> _microMoments(Object? value) =>
    _mapList(value).map((map) {
      return MicroMomentCandidate(
        id: _requiredString(map, 'id'),
        action: _enumByName(
            RoomActionKind.values, map['action'], 'microMoment.action'),
        informationValue: (map['informationValue'] as num).toDouble(),
        userBurden: (map['userBurden'] as num).toDouble(),
        priority: map['priority'] as int? ?? 0,
      );
    }).toList(growable: false);

List<CoupleMemoryItem> _memories(
  Object? value,
  RelationshipBehaviorScenario scenario,
) =>
    _mapList(value).map((map) {
      return CoupleMemoryItem(
        id: _requiredString(map, 'id'),
        ownerId: map['ownerId'] as String? ?? scenario.ownerId,
        partnerId: map['partnerId'] as String? ?? scenario.recipientId,
        kind: _enumByName(CoupleMemoryKind.values, map['kind'], 'memory.kind'),
        key: _requiredString(map, 'key'),
        value: _requiredString(map, 'value'),
        createdAt: _requiredUtc(map, 'createdAt'),
        visibility: _relationshipVisibility(map['visibility']),
        validUntil: _optionalUtc(map, 'validUntil'),
        revokedAt: _optionalUtc(map, 'revokedAt'),
        version: map['version'] as int? ?? 1,
      );
    }).toList(growable: false);

List<CoupleContextEntry<Object?>> _contextEntries(
  Object? value,
  RelationshipBehaviorScenario scenario,
) =>
    _mapList(value).map((map) {
      return CoupleContextEntry<Object?>(
        ownerId: map['ownerId'] as String? ?? scenario.ownerId,
        category: _requiredString(map, 'category'),
        observedAt: _requiredUtc(map, 'observedAt'),
        visibility: _relationshipVisibility(map['visibility']),
        value: map['value'],
      );
    }).toList(growable: false);

CoupleDna _coupleDna(
  Object? value,
  RelationshipBehaviorScenario scenario,
) {
  final map = _objectMap(value);
  return CoupleDna(
    ownerId: map['ownerId'] as String? ?? scenario.ownerId,
    partnerId: map['partnerId'] as String? ?? scenario.recipientId,
    preferredTags: _stringSetOrEmpty(map['preferredTags']),
    dontSuggestTags: _stringSetOrEmpty(map['dontSuggestTags']),
    dontSuggestCandidateIds: _stringSetOrEmpty(map['dontSuggestCandidateIds']),
    maxBudget: map['maxBudget'] as int?,
    maxDurationMinutes: map['maxDurationMinutes'] as int?,
    maxEnergy: map['maxEnergy'] == null
        ? NoveltyEnergy.high
        : _enumByName(NoveltyEnergy.values, map['maxEnergy'], 'dna.maxEnergy'),
    setting: map['setting'] == null
        ? NoveltySetting.either
        : _enumByName(NoveltySetting.values, map['setting'], 'dna.setting'),
    allowIntimacySuggestions: map['allowIntimacySuggestions'] == true,
  );
}

List<NoveltyCandidate> _noveltyCandidates(Object? value) =>
    _mapList(value).map((map) {
      return NoveltyCandidate(
        id: _requiredString(map, 'id'),
        category: _requiredString(map, 'category'),
        title: _requiredString(map, 'title'),
        tags: _stringSetOrEmpty(map['tags']),
        cost: map['cost'] as int,
        durationMinutes: map['durationMinutes'] as int,
        energy:
            _enumByName(NoveltyEnergy.values, map['energy'], 'novelty.energy'),
        setting: _enumByName(
            NoveltySetting.values, map['setting'], 'novelty.setting'),
        requiresIntimacy: map['requiresIntimacy'] == true,
      );
    }).toList(growable: false);

List<NoveltyHistoryEntry> _noveltyHistory(Object? value) =>
    _mapList(value).map((map) {
      return NoveltyHistoryEntry(
        candidateId: _requiredString(map, 'candidateId'),
        usedAt: _requiredUtc(map, 'usedAt'),
      );
    }).toList(growable: false);

List<String> _stringListOrEmpty(Object? value) {
  if (value == null) return const <String>[];
  if (value is! List) throw ArgumentError('Expected a string list');
  return value.map((item) {
    if (item is! String) throw ArgumentError('Expected a string list');
    return item;
  }).toList(growable: false);
}

List<IntimacyPreference> _intimacyPreferences(Object? value) =>
    _mapList(value).map((map) {
      return IntimacyPreference(
        id: _requiredString(map, 'id'),
        ownerId: _requiredString(map, 'ownerId'),
        partnerId: _requiredString(map, 'partnerId'),
        category: _requiredString(map, 'category'),
        optionKey: _requiredString(map, 'optionKey'),
        level: _enumByName(
          IntimacyPreferenceLevel.values,
          map['level'],
          'intimacy.preference.level',
        ),
        createdAt: _requiredUtc(map, 'createdAt'),
        revokedAt: _optionalUtc(map, 'revokedAt'),
        version: map['version'] as int? ?? 1,
      );
    }).toList(growable: false);

List<IntimacyWillingness> _intimacyWillingness(Object? value) =>
    _mapList(value).map((map) {
      return IntimacyWillingness(
        id: _requiredString(map, 'id'),
        ownerId: _requiredString(map, 'ownerId'),
        partnerId: _requiredString(map, 'partnerId'),
        category: _requiredString(map, 'category'),
        optionKey: _requiredString(map, 'optionKey'),
        willingness: _enumByName(
          CurrentWillingness.values,
          map['willingness'],
          'intimacy.willingness',
        ),
        createdAt: _requiredUtc(map, 'createdAt'),
        expiresAt: _requiredUtc(map, 'expiresAt'),
        revokedAt: _optionalUtc(map, 'revokedAt'),
        cooldownUntil: _optionalUtc(map, 'cooldownUntil'),
        version: map['version'] as int? ?? 1,
      );
    }).toList(growable: false);

List<IntimacyBoundary> _intimacyBoundaries(Object? value) =>
    _mapList(value).map((map) {
      return IntimacyBoundary(
        id: _requiredString(map, 'id'),
        ownerId: _requiredString(map, 'ownerId'),
        partnerId: _requiredString(map, 'partnerId'),
        category: _requiredString(map, 'category'),
        optionKey: map['optionKey'] as String?,
        blocked: map['blocked'] == true,
        askFirst: map['askFirst'] == true,
        createdAt: _requiredUtc(map, 'createdAt'),
        revokedAt: _optionalUtc(map, 'revokedAt'),
      );
    }).toList(growable: false);

const Set<String> _mandatoryRelationshipBehaviorTags = <String>{
  'scope',
  'lifecycle',
  'permission',
  'visibility',
  'notificationPrivacy',
  'consent',
  'ordering',
  'suppression',
  'noFallback',
  'clinicalTruth',
  'phase8Reuse',
  'phase9Reuse',
};

List<String> _mandatoryCoverageGaps(RelationshipBehaviorCoverage coverage) {
  final gaps = <String>[];
  for (final family in RelationshipBehaviorScenarioFamily.values) {
    if ((coverage.families[family.name] ?? 0) == 0) {
      gaps.add('family:${family.name}');
    }
  }
  for (final tag in _mandatoryRelationshipBehaviorTags) {
    if ((coverage.riskTags[tag] ?? 0) == 0) gaps.add('tag:$tag');
  }
  gaps.sort();
  return gaps;
}

RelationshipBehaviorScenario _canonicalBehaviorScenario({
  required String id,
  required int seed,
  required DateTime at,
  required RelationshipBehaviorScenarioFamily family,
  required Map<String, Object?> expectedFacts,
  required Set<String> riskTags,
  Map<String, Object?> payload = const <String, Object?>{},
  String ownerId = 'patient-1',
  String recipientId = 'partner-1',
  bool safeControl = false,
  bool adversarial = false,
}) =>
    RelationshipBehaviorScenario(
      id: id,
      schemaVersion: relationshipBehaviorSchemaVersion,
      seed: seed,
      at: at,
      ownerId: ownerId,
      recipientId: recipientId,
      family: family,
      expectedFacts: expectedFacts,
      riskTags: riskTags,
      payload: payload,
      safeControl: safeControl,
      adversarial: adversarial,
    );

Map<String, Object?> _canonicalRelationshipGrant({
  required String id,
  required String ownerId,
  required String recipientId,
  required String category,
  required String capability,
  required String visibility,
  required DateTime createdAt,
}) =>
    <String, Object?>{
      'id': id,
      'ownerId': ownerId,
      'recipientId': recipientId,
      'category': category,
      'capabilities': <String>[capability],
      'visibility': visibility,
      'createdAt': createdAt.toIso8601String(),
      'version': 1,
    };

Map<String, Object?> _canonicalIntimacyPreference({
  required String id,
  required String ownerId,
  required String partnerId,
  required DateTime createdAt,
}) =>
    <String, Object?>{
      'id': id,
      'ownerId': ownerId,
      'partnerId': partnerId,
      'category': 'touch',
      'optionKey': 'kiss',
      'level': 'interested',
      'createdAt': createdAt.toIso8601String(),
      'version': 1,
    };

Map<String, Object?> _canonicalIntimacyWillingness({
  required String id,
  required String ownerId,
  required String partnerId,
  required String willingness,
  required DateTime createdAt,
  required DateTime expiresAt,
  DateTime? cooldownUntil,
}) =>
    <String, Object?>{
      'id': id,
      'ownerId': ownerId,
      'partnerId': partnerId,
      'category': 'touch',
      'optionKey': 'kiss',
      'willingness': willingness,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      if (cooldownUntil != null)
        'cooldownUntil': cooldownUntil.toIso8601String(),
      'version': 1,
    };

Map<String, Object?> _canonicalIntimacyPayload(
  DateTime at, {
  List<Object?> willingness = const <Object?>[],
  List<Object?> boundaries = const <Object?>[],
}) =>
    <String, Object?>{
      'preferences': <Object?>[
        _canonicalIntimacyPreference(
          id: 'pref-a',
          ownerId: 'patient-1',
          partnerId: 'partner-1',
          createdAt: at.subtract(const Duration(hours: 1)),
        ),
        _canonicalIntimacyPreference(
          id: 'pref-b',
          ownerId: 'partner-1',
          partnerId: 'patient-1',
          createdAt: at.subtract(const Duration(hours: 1)),
        ),
      ],
      'willingness': willingness,
      'boundaries': boundaries,
      'grants': <Object?>[
        _canonicalRelationshipGrant(
          id: 'intimacy-a-b',
          ownerId: 'patient-1',
          recipientId: 'partner-1',
          category: 'relationship.intimacy.touch',
          capability: 'intimacy',
          visibility: 'engineOnly',
          createdAt: at.subtract(const Duration(minutes: 5)),
        ),
        _canonicalRelationshipGrant(
          id: 'intimacy-b-a',
          ownerId: 'partner-1',
          recipientId: 'patient-1',
          category: 'relationship.intimacy.touch',
          capability: 'intimacy',
          visibility: 'engineOnly',
          createdAt: at.subtract(const Duration(minutes: 5)),
        ),
      ],
    };

List<RelationshipBehaviorScenario> buildCanonicalRelationshipBehaviorScenarios(
  int seed,
) {
  final at = DateTime.utc(2026, 9, 16, 9);
  final createdAt = at.subtract(const Duration(minutes: 5));
  final scenarios = <RelationshipBehaviorScenario>[
    _canonicalBehaviorScenario(
      id: 'signal.safe.explicit-precedence',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.signalProjection,
      safeControl: true,
      riskTags: const <String>{'ordering', 'phase9Reuse'},
      expectedFacts: const <String, Object?>{
        'selectedSignalIds': <String>['signal-explicit'],
        'projectedSignalIds': <String>['signal-explicit'],
      },
      payload: <String, Object?>{
        'signals': <Object?>[
          <String, Object?>{
            'id': 'signal-derived',
            'kind': 'love',
            'origin': 'derived',
            'createdAt': createdAt.toIso8601String(),
            'version': 5,
          },
          <String, Object?>{
            'id': 'signal-explicit',
            'kind': 'love',
            'origin': 'explicit',
            'createdAt': createdAt.toIso8601String(),
            'version': 1,
          },
        ],
        'grants': <Object?>[
          _canonicalRelationshipGrant(
            id: 'signal-view',
            ownerId: 'patient-1',
            recipientId: 'partner-1',
            category: 'relationship.signal.love',
            capability: 'view',
            visibility: 'fullyShared',
            createdAt: createdAt,
          ),
        ],
      },
    ),
    _canonicalBehaviorScenario(
      id: 'signal.lifecycle.revoked',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.signalProjection,
      adversarial: true,
      riskTags: const <String>{'lifecycle'},
      expectedFacts: const <String, Object?>{
        'selectedSignalIds': <String>[],
        'projectedSignalIds': <String>[],
      },
      payload: <String, Object?>{
        'signals': <Object?>[
          <String, Object?>{
            'id': 'signal-revoked',
            'kind': 'love',
            'origin': 'explicit',
            'createdAt': createdAt.toIso8601String(),
            'revokedAt': at.toIso8601String(),
            'version': 1,
          },
        ],
        'grants': const <Object?>[],
      },
    ),
    _canonicalBehaviorScenario(
      id: 'signal.scope.wrong-recipient',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.signalProjection,
      recipientId: 'partner-2',
      adversarial: true,
      riskTags: const <String>{'scope', 'phase9Reuse'},
      expectedFacts: const <String, Object?>{
        'selectedSignalIds': <String>[],
        'projectedSignalIds': <String>[],
      },
      payload: <String, Object?>{
        'signals': <Object?>[
          <String, Object?>{
            'id': 'signal-wrong-partner',
            'ownerId': 'patient-1',
            'recipientId': 'partner-1',
            'kind': 'love',
            'origin': 'explicit',
            'createdAt': createdAt.toIso8601String(),
          },
        ],
        'grants': const <Object?>[],
      },
    ),
    _canonicalBehaviorScenario(
      id: 'situation.safe.space',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.situation,
      safeControl: true,
      riskTags: const <String>{'permission', 'phase9Reuse'},
      expectedFacts: const <String, Object?>{
        'roomAction': 'giveSpace',
        'weather': 'quiet',
      },
      payload: <String, Object?>{
        'roomSignals': <Object?>[
          <String, Object?>{
            'id': 'room-space',
            'kind': 'needsSpace',
            'createdAt': createdAt.toIso8601String(),
            'priority': 3,
          },
        ],
        'grants': <Object?>[
          _canonicalRelationshipGrant(
            id: 'room-intelligence',
            ownerId: 'patient-1',
            recipientId: 'partner-1',
            category: 'relationship.room.needsSpace',
            capability: 'relationshipIntelligence',
            visibility: 'engineOnly',
            createdAt: createdAt,
          ),
        ],
        'microMoments': const <Object?>[],
      },
    ),
    _canonicalBehaviorScenario(
      id: 'situation.suppression.low-value',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.situation,
      adversarial: true,
      riskTags: const <String>{'suppression'},
      expectedFacts: const <String, Object?>{
        'microMomentSurfaced': false,
        'microMomentReason': 'low_information_value',
      },
      payload: const <String, Object?>{
        'roomSignals': <Object?>[],
        'grants': <Object?>[],
        'microMoments': <Object?>[
          <String, Object?>{
            'id': 'micro-low',
            'action': 'checkIn',
            'informationValue': 0.1,
            'userBurden': 0.9,
          },
        ],
      },
    ),
    _canonicalBehaviorScenario(
      id: 'memory.visibility.engine-only',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.memoryContext,
      adversarial: true,
      riskTags: const <String>{'visibility', 'permission', 'phase9Reuse'},
      expectedFacts: const <String, Object?>{
        'memoryRawValues': <Object?>[null],
      },
      payload: <String, Object?>{
        'operation': 'memory',
        'memories': <Object?>[
          <String, Object?>{
            'id': 'memory-engine-only',
            'kind': 'favorite',
            'key': 'drink',
            'value': 'tea',
            'createdAt': createdAt.toIso8601String(),
            'visibility': 'engineOnly',
          },
        ],
        'grants': <Object?>[
          _canonicalRelationshipGrant(
            id: 'memory-view',
            ownerId: 'patient-1',
            recipientId: 'partner-1',
            category: 'relationship.memory.favorite.drink',
            capability: 'view',
            visibility: 'fullyShared',
            createdAt: createdAt,
          ),
        ],
      },
    ),
    _canonicalBehaviorScenario(
      id: 'novelty.no-fallback.blocked',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.novelty,
      adversarial: true,
      riskTags: const <String>{'noFallback', 'suppression', 'phase9Reuse'},
      expectedFacts: const <String, Object?>{
        'suggestionIds': <String>[],
      },
      payload: <String, Object?>{
        'dna': const <String, Object?>{
          'dontSuggestTags': <String>['blocked'],
        },
        'candidates': const <Object?>[
          <String, Object?>{
            'id': 'novelty-blocked',
            'category': 'date',
            'title': 'Blocked idea',
            'tags': <String>['blocked'],
            'cost': 0,
            'durationMinutes': 10,
            'energy': 'low',
            'setting': 'home',
          },
        ],
        'grants': <Object?>[
          _canonicalRelationshipGrant(
            id: 'novelty-intelligence',
            ownerId: 'patient-1',
            recipientId: 'partner-1',
            category: 'relationship.novelty.date',
            capability: 'relationshipIntelligence',
            visibility: 'engineOnly',
            createdAt: createdAt,
          ),
        ],
      },
    ),
    _canonicalBehaviorScenario(
      id: 'partner-home.scope.same-actor',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.partnerHome,
      adversarial: true,
      riskTags: const <String>{'scope'},
      expectedFacts: const <String, Object?>{
        'homeBuildFailedClosed': true,
      },
      payload: const <String, Object?>{'forceSameActorScope': true},
    ),
    _canonicalBehaviorScenario(
      id: 'notification.safe.generic',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.notification,
      safeControl: true,
      riskTags: const <String>{
        'notificationPrivacy',
        'permission',
        'phase9Reuse',
      },
      expectedFacts: const <String, Object?>{
        'notificationPresented': true,
        'notificationRedacted': true,
        'notificationBody': 'You have a private partner update.',
      },
      payload: <String, Object?>{
        'kind': 'relationship',
        'mode': 'generic',
        'deviceUnlocked': true,
        'category': 'relationship.update',
        'categoryLabel': 'Partner',
        'detail': 'private detail',
        'grants': <Object?>[
          _canonicalRelationshipGrant(
            id: 'notification-notify',
            ownerId: 'patient-1',
            recipientId: 'partner-1',
            category: 'relationship.update',
            capability: 'notify',
            visibility: 'engineOnly',
            createdAt: createdAt,
          ),
        ],
      },
    ),
    _canonicalBehaviorScenario(
      id: 'notification.permission.intimacy-missing',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.notification,
      adversarial: true,
      riskTags: const <String>{
        'notificationPrivacy',
        'permission',
        'consent',
        'phase9Reuse',
      },
      expectedFacts: const <String, Object?>{
        'notificationPresented': false,
      },
      payload: <String, Object?>{
        'kind': 'intimacy',
        'mode': 'generic',
        'deviceUnlocked': true,
        'category': 'relationship.update',
        'categoryLabel': 'Partner',
        'detail': 'private detail',
        'grants': <Object?>[
          _canonicalRelationshipGrant(
            id: 'notification-only-notify',
            ownerId: 'patient-1',
            recipientId: 'partner-1',
            category: 'relationship.update',
            capability: 'notify',
            visibility: 'engineOnly',
            createdAt: createdAt,
          ),
        ],
      },
    ),
    _canonicalBehaviorScenario(
      id: 'playful.safe.truth-first',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.playful,
      safeControl: true,
      riskTags: const <String>{
        'clinicalTruth',
        'phase8Reuse',
        'permission',
      },
      expectedFacts: const <String, Object?>{
        'truthFirst': true,
        'phase8TruthGatePassed': true,
        'playfulApplied': true,
      },
      payload: <String, Object?>{
        'category': 'health',
        'companionText': 'Warm companion',
        'tone': 'warm',
        'truthText': 'Synthetic clinical truth',
        'truthSeverity': 'informational',
        'grants': <Object?>[
          _canonicalRelationshipGrant(
            id: 'playful-health',
            ownerId: 'patient-1',
            recipientId: 'partner-1',
            category: 'relationship.playful.health',
            capability: 'playful',
            visibility: 'engineOnly',
            createdAt: createdAt,
          ),
        ],
      },
    ),
    _canonicalBehaviorScenario(
      id: 'playful.permission.spicy-intimacy-missing',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.playful,
      adversarial: true,
      riskTags: const <String>{'consent', 'permission', 'phase9Reuse'},
      expectedFacts: const <String, Object?>{'playfulApplied': false},
      payload: <String, Object?>{
        'category': 'date',
        'companionText': 'Spicy companion',
        'tone': 'spicy',
        'grants': <Object?>[
          _canonicalRelationshipGrant(
            id: 'playful-date',
            ownerId: 'patient-1',
            recipientId: 'partner-1',
            category: 'relationship.playful.date',
            capability: 'playful',
            visibility: 'engineOnly',
            createdAt: createdAt,
          ),
        ],
      },
    ),
    _canonicalBehaviorScenario(
      id: 'intimacy.preference-not-consent',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.intimacy,
      adversarial: true,
      riskTags: const <String>{'consent', 'permission', 'phase9Reuse'},
      expectedFacts: const <String, Object?>{
        'intimacyDecisionKinds': <String>[],
      },
      payload: _canonicalIntimacyPayload(at),
    ),
    _canonicalBehaviorScenario(
      id: 'intimacy.safe.mutual-yes',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.intimacy,
      safeControl: true,
      riskTags: const <String>{'consent', 'permission', 'phase9Reuse'},
      expectedFacts: const <String, Object?>{
        'intimacyDecisionKinds': <String>['mutuallyWilling'],
      },
      payload: _canonicalIntimacyPayload(
        at,
        willingness: <Object?>[
          _canonicalIntimacyWillingness(
            id: 'willing-a',
            ownerId: 'patient-1',
            partnerId: 'partner-1',
            willingness: 'yes',
            createdAt: at.subtract(const Duration(minutes: 1)),
            expiresAt: at.add(const Duration(minutes: 30)),
          ),
          _canonicalIntimacyWillingness(
            id: 'willing-b',
            ownerId: 'partner-1',
            partnerId: 'patient-1',
            willingness: 'yes',
            createdAt: at.subtract(const Duration(minutes: 1)),
            expiresAt: at.add(const Duration(minutes: 30)),
          ),
        ],
      ),
    ),
    _canonicalBehaviorScenario(
      id: 'intimacy.boundary.hard-block',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.intimacy,
      adversarial: true,
      riskTags: const <String>{'consent'},
      expectedFacts: const <String, Object?>{
        'intimacyDecisionKinds': <String>[],
      },
      payload: _canonicalIntimacyPayload(
        at,
        willingness: <Object?>[
          _canonicalIntimacyWillingness(
            id: 'willing-a',
            ownerId: 'patient-1',
            partnerId: 'partner-1',
            willingness: 'yes',
            createdAt: at.subtract(const Duration(minutes: 1)),
            expiresAt: at.add(const Duration(minutes: 30)),
          ),
          _canonicalIntimacyWillingness(
            id: 'willing-b',
            ownerId: 'partner-1',
            partnerId: 'patient-1',
            willingness: 'yes',
            createdAt: at.subtract(const Duration(minutes: 1)),
            expiresAt: at.add(const Duration(minutes: 30)),
          ),
        ],
        boundaries: <Object?>[
          <String, Object?>{
            'id': 'boundary-a',
            'ownerId': 'patient-1',
            'partnerId': 'partner-1',
            'category': 'touch',
            'optionKey': 'kiss',
            'blocked': true,
            'createdAt': createdAt.toIso8601String(),
          },
        ],
      ),
    ),
    _canonicalBehaviorScenario(
      id: 'preset.safe.minimal',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.preset,
      safeControl: true,
      riskTags: const <String>{'ordering', 'permission', 'phase9Reuse'},
      expectedFacts: const <String, Object?>{
        'presetCategories': <String>['cycle', 'sleep'],
        'presetGrantIds': <String>[
          'rel-patient-1-partner-1-cycle-minimal-v1',
          'rel-patient-1-partner-1-sleep-minimal-v1',
        ],
        'policyCheckAllowed': true,
      },
      payload: const <String, Object?>{
        'preset': 'minimal',
        'categories': <String>['sleep', 'cycle'],
        'policyCheckCategory': 'cycle',
        'policyCheckCapability': 'relationshipIntelligence',
      },
    ),
    _canonicalBehaviorScenario(
      id: 'preset.custom.empty',
      seed: seed,
      at: at,
      family: RelationshipBehaviorScenarioFamily.preset,
      adversarial: true,
      riskTags: const <String>{'permission'},
      expectedFacts: const <String, Object?>{
        'presetGrantIds': <String>[],
      },
      payload: const <String, Object?>{
        'preset': 'custom',
        'categories': <String>['cycle'],
      },
    ),
  ];
  return List<RelationshipBehaviorScenario>.unmodifiable(scenarios);
}

RelationshipBehaviorReport runProductionRelationshipBehaviorSmoke(int seed) =>
    const RelationshipBehaviorSuite(
      observer: ProductionRelationshipBehaviorObserver(),
    ).run(
      seed: seed,
      scenarios: buildCanonicalRelationshipBehaviorScenarios(seed),
      requireMandatoryCoverage: true,
    );
