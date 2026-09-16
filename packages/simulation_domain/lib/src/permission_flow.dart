import 'dart:convert';

import 'package:cycle_permissions/cycle_permissions.dart';
import 'package:cycle_sharing/cycle_sharing.dart';

import 'models.dart';

const int permissionFlowSchemaVersion = 1;

enum PermissionFlowScenarioKind {
  generic,
  sharePolicy,
  relationship,
  composedAccess,
  projection,
}

enum PermissionFlowExpectation {
  mustAllow,
  mustDeny,
  mustProjectWithoutRaw,
  mustProject,
  mustProjectWithRaw,
}

class PermissionFlowValidationException implements Exception {
  const PermissionFlowValidationException(this.message);

  final String message;

  @override
  String toString() => 'PermissionFlowValidationException: $message';
}

class PermissionFlowScenario {
  PermissionFlowScenario({
    required this.id,
    required this.schemaVersion,
    required this.seed,
    required this.at,
    required this.ownerId,
    required this.recipientId,
    required this.kind,
    required this.expectation,
    required this.violationReason,
    Map<String, Object?> payload = const <String, Object?>{},
    this.action,
    this.relationshipCapability,
    this.visibility,
    this.boundary,
    this.escalationAttempt = false,
    this.leakageAttempt = false,
  }) : payload = Map<String, Object?>.unmodifiable(payload) {
    if (schemaVersion != permissionFlowSchemaVersion) {
      throw const PermissionFlowValidationException(
        'Unsupported permission-flow schema version',
      );
    }
    _requireText(id, 'id');
    _requireText(ownerId, 'ownerId');
    _requireText(recipientId, 'recipientId');
    _requireText(violationReason, 'violationReason');
    if (!at.isUtc) {
      throw const PermissionFlowValidationException('at must be UTC');
    }
    for (final entry in <String, String?>{
      'action': action,
      'relationshipCapability': relationshipCapability,
      'visibility': visibility,
      'boundary': boundary,
    }.entries) {
      if (entry.value != null) _requireText(entry.value!, entry.key);
    }
  }

  final String id;
  final int schemaVersion;
  final int seed;
  final DateTime at;
  final String ownerId;
  final String recipientId;
  final PermissionFlowScenarioKind kind;
  final PermissionFlowExpectation expectation;
  final String violationReason;
  final Map<String, Object?> payload;
  final String? action;
  final String? relationshipCapability;
  final String? visibility;
  final String? boundary;
  final bool escalationAttempt;
  final bool leakageAttempt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'schemaVersion': schemaVersion,
        'seed': seed,
        'at': at.toIso8601String(),
        'ownerId': ownerId,
        'recipientId': recipientId,
        'kind': kind.name,
        'expectation': expectation.name,
        'violationReason': violationReason,
        'payload': _canonicalize(payload),
        'action': action,
        'relationshipCapability': relationshipCapability,
        'visibility': visibility,
        'boundary': boundary,
        'escalationAttempt': escalationAttempt,
        'leakageAttempt': leakageAttempt,
      };

  factory PermissionFlowScenario.fromJson(Map<String, Object?> json) {
    final kind = _enumByName(
      PermissionFlowScenarioKind.values,
      json['kind'],
      'kind',
    );
    final expectation = _enumByName(
      PermissionFlowExpectation.values,
      json['expectation'],
      'expectation',
    );
    return PermissionFlowScenario(
      id: json['id'] as String,
      schemaVersion: json['schemaVersion'] as int,
      seed: json['seed'] as int,
      at: _parseUtc(json['at'], 'at'),
      ownerId: json['ownerId'] as String,
      recipientId: json['recipientId'] as String,
      kind: kind,
      expectation: expectation,
      violationReason: json['violationReason'] as String,
      payload: _objectMap(json['payload']),
      action: json['action'] as String?,
      relationshipCapability: json['relationshipCapability'] as String?,
      visibility: json['visibility'] as String?,
      boundary: json['boundary'] as String?,
      escalationAttempt: json['escalationAttempt'] as bool? ?? false,
      leakageAttempt: json['leakageAttempt'] as bool? ?? false,
    );
  }
}

class PermissionFlowObservation {
  const PermissionFlowObservation({
    required this.allowed,
    this.projected = false,
    this.exposesRawValue = false,
    this.reason = 'observed',
    this.matchedGrantId,
    this.matchedGenericGrantId,
    this.matchedRelationshipGrantId,
    this.visibility,
    this.capabilities = const <String, bool>{},
  });

  final bool allowed;
  final bool projected;
  final bool exposesRawValue;
  final String reason;
  final String? matchedGrantId;
  final String? matchedGenericGrantId;
  final String? matchedRelationshipGrantId;
  final String? visibility;
  final Map<String, bool> capabilities;

  Map<String, Object?> toJson() => <String, Object?>{
        'allowed': allowed,
        'projected': projected,
        'exposesRawValue': exposesRawValue,
        'reason': reason,
        'matchedGrantId': matchedGrantId,
        'matchedGenericGrantId': matchedGenericGrantId,
        'matchedRelationshipGrantId': matchedRelationshipGrantId,
        'visibility': visibility,
        'capabilities': _canonicalize(capabilities),
      };
}

abstract class PermissionFlowObserver {
  const PermissionFlowObserver();

  PermissionFlowObservation observe(PermissionFlowScenario scenario);
}

class ProductionPermissionFlowObserver extends PermissionFlowObserver {
  const ProductionPermissionFlowObserver({
    this.permissionEvaluator = const PermissionEvaluator(),
    this.privacySimulator = const PrivacySimulator(),
    this.sharePolicy = const SharePolicy(),
    this.relationshipFirewall = const RelationshipPermissionFirewall(),
    this.relationshipAccessGate = const RelationshipAccessGate(),
    this.relationshipProjector = const RelationshipContextProjector(),
  });

  final PermissionEvaluator permissionEvaluator;
  final PrivacySimulator privacySimulator;
  final SharePolicy sharePolicy;
  final RelationshipPermissionFirewall relationshipFirewall;
  final RelationshipAccessGate relationshipAccessGate;
  final RelationshipContextProjector relationshipProjector;

  @override
  PermissionFlowObservation observe(PermissionFlowScenario scenario) {
    return switch (scenario.kind) {
      PermissionFlowScenarioKind.generic => _observeGeneric(scenario),
      PermissionFlowScenarioKind.sharePolicy => _observeSharePolicy(scenario),
      PermissionFlowScenarioKind.relationship => _observeRelationship(scenario),
      PermissionFlowScenarioKind.composedAccess => _observeComposed(scenario),
      PermissionFlowScenarioKind.projection => _observeProjection(scenario),
    };
  }

  PermissionFlowObservation _observeGeneric(PermissionFlowScenario scenario) {
    final requestMap = _requiredMap(scenario.payload, 'request');
    final grants = _permissionGrants(scenario.payload['grants']);
    final request = PermissionRequest(
      ownerId: scenario.ownerId,
      recipientId: scenario.recipientId,
      action:
          _enumByName(PermissionAction.values, requestMap['action'], 'action'),
      category: _requiredString(requestMap, 'category'),
      field: _optionalString(requestMap['field']),
      purpose: _optionalString(requestMap['purpose']),
      at: scenario.at,
      resourceObservedAt:
          _optionalUtc(requestMap['resourceObservedAt'], 'resourceObservedAt'),
    );
    final decision =
        permissionEvaluator.evaluate(request: request, grants: grants);
    final simulated = privacySimulator
        .simulate(requests: <PermissionRequest>[request], grants: grants)
        .entries
        .single
        .decision;
    if (decision.allowed != simulated.allowed ||
        decision.matchedGrantId != simulated.matchedGrantId) {
      throw const PermissionFlowValidationException(
        'PrivacySimulator diverged from PermissionEvaluator',
      );
    }
    return PermissionFlowObservation(
      allowed: decision.allowed,
      reason: decision.reason,
      matchedGrantId: decision.matchedGrantId,
    );
  }

  PermissionFlowObservation _observeSharePolicy(
      PermissionFlowScenario scenario) {
    final grants = _permissionGrants(scenario.payload['grants']);
    final decision = sharePolicy.evaluate(
      ownerId: scenario.ownerId,
      recipientId: scenario.recipientId,
      category: _requiredString(scenario.payload, 'category'),
      at: scenario.at,
      grants: grants,
      resourceObservedAt: _optionalUtc(
        scenario.payload['resourceObservedAt'],
        'resourceObservedAt',
      ),
    );
    final capabilities = <String, bool>{
      'view': decision.canView,
      'notify': decision.canNotify,
      'backup': decision.canBackup,
    };
    return PermissionFlowObservation(
      allowed: capabilities.values.any((value) => value),
      reason: 'share_policy',
      capabilities: capabilities,
    );
  }

  PermissionFlowObservation _observeRelationship(
      PermissionFlowScenario scenario) {
    final capability = _enumByName(
      RelationshipCapability.values,
      scenario.payload['capability'] ?? scenario.relationshipCapability,
      'relationshipCapability',
    );
    final decision = relationshipFirewall.evaluate(
      request: RelationshipAccessRequest(
        ownerId: scenario.ownerId,
        recipientId: scenario.recipientId,
        category: _requiredString(scenario.payload, 'category'),
        capability: capability,
        at: scenario.at,
      ),
      grants: _relationshipGrants(scenario.payload['relationshipGrants']),
    );
    return PermissionFlowObservation(
      allowed: decision.allowed,
      reason: decision.reason,
      matchedGrantId: decision.matchedGrantId,
      visibility: decision.visibility?.name,
    );
  }

  PermissionFlowObservation _observeComposed(PermissionFlowScenario scenario) {
    final decision = relationshipAccessGate.evaluate(
      ownerId: scenario.ownerId,
      recipientId: scenario.recipientId,
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
      genericPurpose: _optionalString(scenario.payload['genericPurpose']),
      resourceObservedAt: _optionalUtc(
        scenario.payload['resourceObservedAt'],
        'resourceObservedAt',
      ),
    );
    return PermissionFlowObservation(
      allowed: decision.allowed,
      reason: decision.reason,
      matchedGenericGrantId: decision.genericGrantId,
      matchedRelationshipGrantId: decision.relationshipGrantId,
    );
  }

  PermissionFlowObservation _observeProjection(
      PermissionFlowScenario scenario) {
    final itemMap = _requiredMap(scenario.payload, 'item');
    final item = RelationshipContextItem<Object?>(
      ownerId: scenario.ownerId,
      category: _requiredString(itemMap, 'category'),
      value: itemMap['value'],
      observedAt: _requiredUtcValue(itemMap['observedAt'], 'observedAt'),
      visibility: _enumByName(
        RelationshipVisibility.values,
        itemMap['visibility'],
        'item.visibility',
      ),
    );
    final projection = relationshipProjector.project<Object?>(
      item: item,
      recipientId: scenario.recipientId,
      capability: _enumByName(
        RelationshipCapability.values,
        scenario.payload['capability'] ?? scenario.relationshipCapability,
        'relationshipCapability',
      ),
      at: scenario.at,
      grants: _relationshipGrants(scenario.payload['relationshipGrants']),
    );
    return PermissionFlowObservation(
      allowed: projection != null,
      projected: projection != null,
      exposesRawValue: projection?.exposesRawValue ?? false,
      reason: projection == null ? 'projection_denied' : 'projected',
      visibility: projection?.visibility.name,
    );
  }
}

List<PermissionFlowScenario> buildCanonicalPermissionFlowScenarios(int seed) {
  final at = DateTime.utc(2026, 9, 16, 9);
  final scenarios = <PermissionFlowScenario>[
    for (final action in <String>['view', 'notify', 'backup', 'export'])
      _canonicalGenericScenario(
        id: 'generic.safe.$action',
        seed: seed,
        at: at,
        requestAction: action,
        grantActions: <String>[action],
        expectation: PermissionFlowExpectation.mustAllow,
        violationReason: 'default_deny_bypass',
      ),
    _canonicalGenericScenario(
      id: 'generic.actor.wrong-owner',
      seed: seed,
      at: at,
      ownerId: 'patient-2',
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'actor_scope_escape',
    ),
    _canonicalGenericScenario(
      id: 'generic.actor.wrong-recipient',
      seed: seed,
      at: at,
      recipientId: 'partner-2',
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'actor_scope_escape',
    ),
    _canonicalGenericScenario(
      id: 'generic.default-deny',
      seed: seed,
      at: at,
      includeGrant: false,
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'default_deny_bypass',
    ),
    _canonicalGenericScenario(
      id: 'generic.action.view-to-notify',
      seed: seed,
      at: at,
      requestAction: 'notify',
      grantActions: const <String>['view'],
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'action_escalation',
      escalationAttempt: true,
    ),
    _canonicalGenericScenario(
      id: 'generic.action.notify-to-backup',
      seed: seed,
      at: at,
      requestAction: 'backup',
      grantActions: const <String>['notify'],
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'action_escalation',
      escalationAttempt: true,
    ),
    _canonicalGenericScenario(
      id: 'generic.action.backup-to-export',
      seed: seed,
      at: at,
      requestAction: 'export',
      grantActions: const <String>['backup'],
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'action_escalation',
      escalationAttempt: true,
    ),
    _canonicalGenericScenario(
      id: 'generic.scope.category',
      seed: seed,
      at: at,
      requestCategory: 'sleep',
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'category_scope_escape',
    ),
    _canonicalGenericScenario(
      id: 'generic.scope.field',
      seed: seed,
      at: at,
      requestField: 'pain',
      grantFields: const <String>['flow'],
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'field_scope_escape',
    ),
    _canonicalGenericScenario(
      id: 'generic.scope.purpose',
      seed: seed,
      at: at,
      requestPurpose: 'intimacy',
      grantPurposes: const <String>['support'],
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'purpose_scope_escape',
    ),
    _canonicalGenericScenario(
      id: 'generic.scope.no-purpose-explicit-grant',
      seed: seed,
      at: at,
      grantPurposes: const <String>['support'],
      expectation: PermissionFlowExpectation.mustAllow,
      violationReason: 'purpose_scope_escape',
    ),
    _canonicalGenericScenario(
      id: 'generic.grant.start-exact',
      seed: seed,
      at: at,
      validFrom: at,
      boundary: 'grantStart',
      expectation: PermissionFlowExpectation.mustAllow,
      violationReason: 'grant_time_escape',
    ),
    _canonicalGenericScenario(
      id: 'generic.grant.end-exact',
      seed: seed,
      at: at,
      validUntil: at,
      boundary: 'grantEnd',
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'grant_time_escape',
    ),
    _canonicalGenericScenario(
      id: 'generic.revocation.exact',
      seed: seed,
      at: at,
      revokedAt: at,
      boundary: 'revocation',
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'revocation_breach',
    ),
    _canonicalGenericScenario(
      id: 'generic.data-from.exact',
      seed: seed,
      at: at,
      resourceObservedAt: at,
      dataFrom: at,
      boundary: 'dataFrom',
      expectation: PermissionFlowExpectation.mustAllow,
      violationReason: 'data_window_escape',
    ),
    _canonicalGenericScenario(
      id: 'generic.data-until.exact',
      seed: seed,
      at: at,
      resourceObservedAt: at,
      dataUntil: at,
      boundary: 'dataUntil',
      expectation: PermissionFlowExpectation.mustAllow,
      violationReason: 'data_window_escape',
    ),
    _canonicalGenericScenario(
      id: 'generic.data-before-window',
      seed: seed,
      at: at,
      resourceObservedAt: at.subtract(const Duration(minutes: 1)),
      dataFrom: at,
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'data_window_escape',
    ),
    _canonicalGenericScenario(
      id: 'generic.data-after-window',
      seed: seed,
      at: at,
      resourceObservedAt: at.add(const Duration(minutes: 1)),
      dataUntil: at,
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'data_window_escape',
    ),
    _canonicalSharePolicyScenario(seed: seed, at: at),
    for (final capability in <String>[
      'view',
      'notify',
      'relationshipIntelligence',
      'playful',
      'intimacy',
    ])
      _canonicalRelationshipScenario(
        id: 'relationship.safe.$capability',
        seed: seed,
        at: at,
        capability: capability,
        expectation: PermissionFlowExpectation.mustAllow,
        violationReason: 'relationship_capability_escalation',
      ),
    _canonicalRelationshipScenario(
      id: 'relationship.generic-does-not-imply-intimacy',
      seed: seed,
      at: at,
      capability: 'intimacy',
      includeGrant: false,
      expectation: PermissionFlowExpectation.mustDeny,
      violationReason: 'relationship_capability_escalation',
      escalationAttempt: true,
    ),
    ..._canonicalComposedScenarios(seed: seed, at: at),
    ..._canonicalProjectionScenarios(seed: seed, at: at),
  ];
  return List<PermissionFlowScenario>.unmodifiable(scenarios);
}

PermissionFlowReport runProductionPermissionFlowSmoke(int seed) =>
    const PermissionFlowSuite().run(
      seed: seed,
      scenarios: buildCanonicalPermissionFlowScenarios(seed),
    );

PermissionFlowScenario _canonicalGenericScenario({
  required String id,
  required int seed,
  required DateTime at,
  String ownerId = 'patient-1',
  String recipientId = 'partner-1',
  String requestAction = 'view',
  String requestCategory = 'cycle',
  String? requestField,
  String? requestPurpose,
  List<String> grantActions = const <String>['view'],
  List<String> grantCategories = const <String>['cycle'],
  List<String> grantFields = const <String>[],
  List<String> grantPurposes = const <String>[],
  DateTime? validFrom,
  DateTime? validUntil,
  DateTime? revokedAt,
  DateTime? resourceObservedAt,
  DateTime? dataFrom,
  DateTime? dataUntil,
  bool includeGrant = true,
  required PermissionFlowExpectation expectation,
  required String violationReason,
  String? boundary,
  bool escalationAttempt = false,
}) {
  final grant = <String, Object?>{
    'id': 'grant-$id',
    'ownerId': 'patient-1',
    'recipientId': 'partner-1',
    'recipientKind': 'partner',
    'actions': grantActions,
    'scope': <String, Object?>{
      'categories': grantCategories,
      'fields': grantFields,
      'purposes': grantPurposes,
      'validFrom': validFrom?.toIso8601String(),
      'validUntil': validUntil?.toIso8601String(),
      'dataFrom': dataFrom?.toIso8601String(),
      'dataUntil': dataUntil?.toIso8601String(),
    },
    'createdAt': at.subtract(const Duration(hours: 1)).toIso8601String(),
    'revokedAt': revokedAt?.toIso8601String(),
    'version': 1,
  };
  return PermissionFlowScenario(
    id: id,
    schemaVersion: permissionFlowSchemaVersion,
    seed: seed,
    at: at,
    ownerId: ownerId,
    recipientId: recipientId,
    kind: PermissionFlowScenarioKind.generic,
    expectation: expectation,
    violationReason: violationReason,
    action: requestAction,
    boundary: boundary,
    escalationAttempt: escalationAttempt,
    payload: <String, Object?>{
      'request': <String, Object?>{
        'action': requestAction,
        'category': requestCategory,
        'field': requestField,
        'purpose': requestPurpose,
        'resourceObservedAt': resourceObservedAt?.toIso8601String(),
      },
      'grants': includeGrant ? <Object?>[grant] : const <Object?>[],
    },
  );
}

PermissionFlowScenario _canonicalSharePolicyScenario({
  required int seed,
  required DateTime at,
}) =>
    PermissionFlowScenario(
      id: 'share-policy.view-only',
      schemaVersion: permissionFlowSchemaVersion,
      seed: seed,
      at: at,
      ownerId: 'patient-1',
      recipientId: 'partner-1',
      kind: PermissionFlowScenarioKind.sharePolicy,
      expectation: PermissionFlowExpectation.mustAllow,
      violationReason: 'default_deny_bypass',
      action: 'view',
      payload: <String, Object?>{
        'category': 'cycle',
        'grants': <Object?>[
          <String, Object?>{
            'id': 'grant-share-view-only',
            'ownerId': 'patient-1',
            'recipientId': 'partner-1',
            'recipientKind': 'partner',
            'actions': <String>['view'],
            'scope': <String, Object?>{
              'categories': <String>['cycle'],
              'fields': const <String>[],
              'purposes': const <String>[],
            },
            'createdAt':
                at.subtract(const Duration(hours: 1)).toIso8601String(),
            'version': 1,
          },
        ],
      },
    );

PermissionFlowScenario _canonicalRelationshipScenario({
  required String id,
  required int seed,
  required DateTime at,
  required String capability,
  required PermissionFlowExpectation expectation,
  required String violationReason,
  bool includeGrant = true,
  bool escalationAttempt = false,
}) {
  final visibility = capability == 'view' ? 'fullyShared' : 'engineOnly';
  return PermissionFlowScenario(
    id: id,
    schemaVersion: permissionFlowSchemaVersion,
    seed: seed,
    at: at,
    ownerId: 'patient-1',
    recipientId: 'partner-1',
    kind: PermissionFlowScenarioKind.relationship,
    expectation: expectation,
    violationReason: violationReason,
    relationshipCapability: capability,
    visibility: visibility,
    escalationAttempt: escalationAttempt,
    payload: <String, Object?>{
      'category': 'cycle',
      'capability': capability,
      'relationshipGrants': includeGrant
          ? <Object?>[
              <String, Object?>{
                'id': 'grant-$id',
                'ownerId': 'patient-1',
                'recipientId': 'partner-1',
                'category': 'cycle',
                'capabilities': <String>[capability],
                'visibility': visibility,
                'createdAt':
                    at.subtract(const Duration(hours: 1)).toIso8601String(),
                'version': 1,
              },
            ]
          : const <Object?>[],
    },
  );
}

List<PermissionFlowScenario> _canonicalComposedScenarios({
  required int seed,
  required DateTime at,
}) {
  PermissionFlowScenario build({
    required String id,
    required String action,
    required bool genericGrant,
    required bool relationshipGrant,
    required PermissionFlowExpectation expectation,
  }) {
    final capability = action;
    final relationshipVisibility =
        action == 'view' ? 'fullyShared' : 'engineOnly';
    return PermissionFlowScenario(
      id: id,
      schemaVersion: permissionFlowSchemaVersion,
      seed: seed,
      at: at,
      ownerId: 'patient-1',
      recipientId: 'partner-1',
      kind: PermissionFlowScenarioKind.composedAccess,
      expectation: expectation,
      violationReason: 'composed_gate_bypass',
      action: action,
      relationshipCapability: capability,
      payload: <String, Object?>{
        'genericCategory': 'cycle',
        'relationshipCategory': 'cycle',
        'genericAction': action,
        'relationshipCapability': capability,
        'genericGrants': genericGrant
            ? <Object?>[
                <String, Object?>{
                  'id': 'generic-$id',
                  'ownerId': 'patient-1',
                  'recipientId': 'partner-1',
                  'recipientKind': 'partner',
                  'actions': <String>[action],
                  'scope': <String, Object?>{
                    'categories': <String>['cycle'],
                    'fields': const <String>[],
                    'purposes': const <String>[],
                  },
                  'createdAt':
                      at.subtract(const Duration(hours: 1)).toIso8601String(),
                  'version': 1,
                },
              ]
            : const <Object?>[],
        'relationshipGrants': relationshipGrant
            ? <Object?>[
                <String, Object?>{
                  'id': 'relationship-$id',
                  'ownerId': 'patient-1',
                  'recipientId': 'partner-1',
                  'category': 'cycle',
                  'capabilities': <String>[capability],
                  'visibility': relationshipVisibility,
                  'createdAt':
                      at.subtract(const Duration(hours: 1)).toIso8601String(),
                  'version': 1,
                },
              ]
            : const <Object?>[],
      },
    );
  }

  return <PermissionFlowScenario>[
    for (final action in <String>[
      'view',
      'notify'
    ]) ...<PermissionFlowScenario>[
      build(
        id: 'composed.$action.both',
        action: action,
        genericGrant: true,
        relationshipGrant: true,
        expectation: PermissionFlowExpectation.mustAllow,
      ),
      build(
        id: 'composed.$action.generic-only',
        action: action,
        genericGrant: true,
        relationshipGrant: false,
        expectation: PermissionFlowExpectation.mustDeny,
      ),
      build(
        id: 'composed.$action.relationship-only',
        action: action,
        genericGrant: false,
        relationshipGrant: true,
        expectation: PermissionFlowExpectation.mustDeny,
      ),
    ],
  ];
}

List<PermissionFlowScenario> _canonicalProjectionScenarios({
  required int seed,
  required DateTime at,
}) {
  PermissionFlowScenario build({
    required String id,
    required String itemVisibility,
    required String grantVisibility,
    required String effectiveVisibility,
    required String capability,
    required PermissionFlowExpectation expectation,
    required String violationReason,
    required bool leakageAttempt,
  }) =>
      PermissionFlowScenario(
        id: id,
        schemaVersion: permissionFlowSchemaVersion,
        seed: seed,
        at: at,
        ownerId: 'patient-1',
        recipientId: 'partner-1',
        kind: PermissionFlowScenarioKind.projection,
        expectation: expectation,
        violationReason: violationReason,
        relationshipCapability: capability,
        visibility: effectiveVisibility,
        leakageAttempt: leakageAttempt,
        payload: <String, Object?>{
          'item': <String, Object?>{
            'category': 'cycle',
            'value': 'sensitive-value',
            'observedAt':
                at.subtract(const Duration(minutes: 30)).toIso8601String(),
            'visibility': itemVisibility,
          },
          'capability': capability,
          'relationshipGrants': <Object?>[
            <String, Object?>{
              'id': 'grant-$id',
              'ownerId': 'patient-1',
              'recipientId': 'partner-1',
              'category': 'cycle',
              'capabilities': <String>[capability],
              'visibility': grantVisibility,
              'createdAt':
                  at.subtract(const Duration(hours: 1)).toIso8601String(),
              'version': 1,
            },
          ],
        },
      );

  return <PermissionFlowScenario>[
    build(
      id: 'projection.private.raw-ceiling',
      itemVisibility: 'private',
      grantVisibility: 'engineOnly',
      effectiveVisibility: 'private',
      capability: 'relationshipIntelligence',
      expectation: PermissionFlowExpectation.mustProjectWithoutRaw,
      violationReason: 'private_data_exposed',
      leakageAttempt: true,
    ),
    build(
      id: 'projection.engine-only.raw-ceiling',
      itemVisibility: 'fullyShared',
      grantVisibility: 'engineOnly',
      effectiveVisibility: 'engineOnly',
      capability: 'relationshipIntelligence',
      expectation: PermissionFlowExpectation.mustProjectWithoutRaw,
      violationReason: 'engine_only_data_exposed',
      leakageAttempt: true,
    ),
    build(
      id: 'projection.abstract.raw-ceiling',
      itemVisibility: 'fullyShared',
      grantVisibility: 'abstractShared',
      effectiveVisibility: 'abstractShared',
      capability: 'view',
      expectation: PermissionFlowExpectation.mustProjectWithoutRaw,
      violationReason: 'abstract_data_exposed',
      leakageAttempt: true,
    ),
    build(
      id: 'projection.full.raw-allowed',
      itemVisibility: 'fullyShared',
      grantVisibility: 'fullyShared',
      effectiveVisibility: 'fullyShared',
      capability: 'view',
      expectation: PermissionFlowExpectation.mustProject,
      violationReason: 'fully_shared_projection_missing',
      leakageAttempt: false,
    ),
  ];
}

class PermissionFlowSuite {
  const PermissionFlowSuite({
    this.observer = const ProductionPermissionFlowObserver(),
  });

  final PermissionFlowObserver observer;

  PermissionFlowResult evaluate(PermissionFlowScenario scenario) {
    final observation = observer.observe(scenario);
    final passed = switch (scenario.expectation) {
      PermissionFlowExpectation.mustAllow => observation.allowed,
      PermissionFlowExpectation.mustDeny => !observation.allowed,
      PermissionFlowExpectation.mustProjectWithoutRaw =>
        observation.projected && !observation.exposesRawValue,
      PermissionFlowExpectation.mustProject => observation.projected,
      PermissionFlowExpectation.mustProjectWithRaw =>
        observation.projected && observation.exposesRawValue,
    };
    return PermissionFlowResult(
      scenarioId: scenario.id,
      passed: passed,
      reasonCode: passed ? 'contract_satisfied' : scenario.violationReason,
      evaluatedAt: scenario.at,
      evidence: observation.toJson(),
    );
  }

  PermissionFlowReport run({
    required int seed,
    required Iterable<PermissionFlowScenario> scenarios,
  }) {
    final ordered = List<PermissionFlowScenario>.from(scenarios)
      ..sort((a, b) => a.id.compareTo(b.id));
    final results = <PermissionFlowResult>[];
    for (final scenario in ordered) {
      try {
        results.add(evaluate(scenario));
      } on Object catch (error) {
        results.add(
          PermissionFlowResult(
            scenarioId: scenario.id,
            passed: false,
            reasonCode: 'malformed_input',
            evaluatedAt: scenario.at,
            evidence: <String, Object?>{
              'errorType': error.runtimeType.toString(),
              'message': error.toString(),
            },
          ),
        );
      }
    }
    return PermissionFlowReport(
      seed: seed,
      results: results,
      coverage: PermissionFlowCoverage.fromRun(
        scenarios: ordered,
        results: results,
      ),
    );
  }
}

class PermissionFlowResult {
  PermissionFlowResult({
    required this.scenarioId,
    required this.passed,
    required this.reasonCode,
    required this.evaluatedAt,
    Map<String, Object?> evidence = const <String, Object?>{},
  }) : evidence = Map<String, Object?>.unmodifiable(evidence) {
    _requireText(scenarioId, 'scenarioId');
    _requireText(reasonCode, 'reasonCode');
    if (!evaluatedAt.isUtc) {
      throw const PermissionFlowValidationException(
        'Permission-flow result timestamps must be UTC',
      );
    }
  }

  final String scenarioId;
  final bool passed;
  final String reasonCode;
  final DateTime evaluatedAt;
  final Map<String, Object?> evidence;

  InvariantSeverity get severity => InvariantSeverity.s4;

  Map<String, Object?> toJson() => <String, Object?>{
        'scenarioId': scenarioId,
        'passed': passed,
        'severity': severity.name,
        'reasonCode': reasonCode,
        'evaluatedAt': evaluatedAt.toIso8601String(),
        'evidence': _canonicalize(evidence),
      };

  factory PermissionFlowResult.fromJson(Map<String, Object?> json) =>
      PermissionFlowResult(
        scenarioId: json['scenarioId'] as String,
        passed: json['passed'] as bool,
        reasonCode: json['reasonCode'] as String,
        evaluatedAt: _parseUtc(json['evaluatedAt'], 'evaluatedAt'),
        evidence: _objectMap(json['evidence']),
      );
}

class PermissionFlowCoverage {
  const PermissionFlowCoverage({
    required this.configuredScenarios,
    required this.evaluatedScenarios,
    required this.passedScenarios,
    required this.failedScenarios,
    required this.malformedInputFailures,
    required this.scenarioKinds,
    required this.actions,
    required this.relationshipCapabilities,
    required this.visibilities,
    required this.boundaries,
    required this.escalationAttempts,
    required this.leakageAttempts,
  });

  factory PermissionFlowCoverage.fromRun({
    required Iterable<PermissionFlowScenario> scenarios,
    required Iterable<PermissionFlowResult> results,
  }) {
    final scenarioList = List<PermissionFlowScenario>.from(scenarios);
    final resultList = List<PermissionFlowResult>.from(results);
    Map<String, int> count(Iterable<String?> values) {
      final output = <String, int>{};
      for (final value in values.whereType<String>()) {
        output[value] = (output[value] ?? 0) + 1;
      }
      return Map<String, int>.unmodifiable(output);
    }

    return PermissionFlowCoverage(
      configuredScenarios: scenarioList.length,
      evaluatedScenarios: resultList.length,
      passedScenarios: resultList.where((item) => item.passed).length,
      failedScenarios: resultList.where((item) => !item.passed).length,
      malformedInputFailures: resultList
          .where((item) => item.reasonCode == 'malformed_input')
          .length,
      scenarioKinds: count(scenarioList.map((item) => item.kind.name)),
      actions: count(scenarioList.map((item) => item.action)),
      relationshipCapabilities:
          count(scenarioList.map((item) => item.relationshipCapability)),
      visibilities: count(scenarioList.map((item) => item.visibility)),
      boundaries: count(scenarioList.map((item) => item.boundary)),
      escalationAttempts:
          scenarioList.where((item) => item.escalationAttempt).length,
      leakageAttempts: scenarioList.where((item) => item.leakageAttempt).length,
    );
  }

  const PermissionFlowCoverage.empty()
      : configuredScenarios = 0,
        evaluatedScenarios = 0,
        passedScenarios = 0,
        failedScenarios = 0,
        malformedInputFailures = 0,
        scenarioKinds = const <String, int>{},
        actions = const <String, int>{},
        relationshipCapabilities = const <String, int>{},
        visibilities = const <String, int>{},
        boundaries = const <String, int>{},
        escalationAttempts = 0,
        leakageAttempts = 0;

  final int configuredScenarios;
  final int evaluatedScenarios;
  final int passedScenarios;
  final int failedScenarios;
  final int malformedInputFailures;
  final Map<String, int> scenarioKinds;
  final Map<String, int> actions;
  final Map<String, int> relationshipCapabilities;
  final Map<String, int> visibilities;
  final Map<String, int> boundaries;
  final int escalationAttempts;
  final int leakageAttempts;

  Map<String, Object?> toJson() => <String, Object?>{
        'configuredScenarios': configuredScenarios,
        'evaluatedScenarios': evaluatedScenarios,
        'passedScenarios': passedScenarios,
        'failedScenarios': failedScenarios,
        'malformedInputFailures': malformedInputFailures,
        'scenarioKinds': _canonicalize(scenarioKinds),
        'actions': _canonicalize(actions),
        'relationshipCapabilities': _canonicalize(relationshipCapabilities),
        'visibilities': _canonicalize(visibilities),
        'boundaries': _canonicalize(boundaries),
        'escalationAttempts': escalationAttempts,
        'leakageAttempts': leakageAttempts,
      };

  factory PermissionFlowCoverage.fromJson(Map<String, Object?> json) =>
      PermissionFlowCoverage(
        configuredScenarios: json['configuredScenarios'] as int,
        evaluatedScenarios: json['evaluatedScenarios'] as int,
        passedScenarios: json['passedScenarios'] as int,
        failedScenarios: json['failedScenarios'] as int,
        malformedInputFailures: json['malformedInputFailures'] as int,
        scenarioKinds: _intMap(json['scenarioKinds']),
        actions: _intMap(json['actions']),
        relationshipCapabilities: _intMap(json['relationshipCapabilities']),
        visibilities: _intMap(json['visibilities']),
        boundaries: _intMap(json['boundaries']),
        escalationAttempts: json['escalationAttempts'] as int,
        leakageAttempts: json['leakageAttempts'] as int,
      );
}

class PermissionFlowReport {
  PermissionFlowReport({
    required this.seed,
    required Iterable<PermissionFlowResult> results,
    required this.coverage,
  }) : results = List<PermissionFlowResult>.unmodifiable(
          List<PermissionFlowResult>.from(results)
            ..sort((a, b) => a.scenarioId.compareTo(b.scenarioId)),
        );

  final int seed;
  final List<PermissionFlowResult> results;
  final PermissionFlowCoverage coverage;

  bool get syntheticEvidenceOnly => true;
  bool get passed => results.every((item) => item.passed);
  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': permissionFlowSchemaVersion,
        'seed': seed,
        'syntheticEvidenceOnly': true,
        'passed': passed,
        'coverage': coverage.toJson(),
        'results': results.map((item) => item.toJson()).toList(growable: false),
      };

  String toNormalizedJson() => jsonEncode(_canonicalize(toJson()));

  factory PermissionFlowReport.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != permissionFlowSchemaVersion) {
      throw const PermissionFlowValidationException(
        'Unsupported permission-flow report schema version',
      );
    }
    final rawResults = json['results'];
    if (rawResults is! List) {
      throw const PermissionFlowValidationException(
        'Permission-flow report results must be a list',
      );
    }
    return PermissionFlowReport(
      seed: json['seed'] as int,
      results: rawResults
          .map((item) => PermissionFlowResult.fromJson(_objectMap(item)))
          .toList(growable: false),
      coverage: PermissionFlowCoverage.fromJson(_objectMap(json['coverage'])),
    );
  }
}

T _enumByName<T extends Enum>(Iterable<T> values, Object? raw, String field) {
  if (raw is! String) {
    throw PermissionFlowValidationException('$field must be a string');
  }
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw PermissionFlowValidationException('Unsupported $field: $raw');
}

DateTime _parseUtc(Object? raw, String field) {
  if (raw is! String) {
    throw PermissionFlowValidationException('$field must be an ISO timestamp');
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || !parsed.isUtc) {
    throw PermissionFlowValidationException('$field must be UTC');
  }
  return parsed;
}

void _requireText(String value, String field) {
  if (value.trim().isEmpty) {
    throw PermissionFlowValidationException('$field must not be blank');
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) {
    throw const PermissionFlowValidationException('Expected an object');
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

Map<String, Object?> _requiredMap(
  Map<String, Object?> source,
  String key,
) {
  final value = source[key];
  if (value is! Map) {
    throw PermissionFlowValidationException('$key must be an object');
  }
  return _objectMap(value);
}

String _requiredString(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is! String || value.trim().isEmpty) {
    throw PermissionFlowValidationException('$key is required');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const PermissionFlowValidationException(
      'Optional string must not be blank',
    );
  }
  return value;
}

DateTime _requiredUtcValue(Object? value, String field) =>
    _parseUtc(value, field);

DateTime? _optionalUtc(Object? value, String field) =>
    value == null ? null : _parseUtc(value, field);

Set<String> _stringSet(Object? value) {
  if (value == null) return const <String>{};
  if (value is! List) {
    throw const PermissionFlowValidationException('Expected a string list');
  }
  final output = <String>{};
  for (final item in value) {
    if (item is! String || item.trim().isEmpty) {
      throw const PermissionFlowValidationException('Expected a string list');
    }
    output.add(item);
  }
  return output;
}

List<PermissionGrant> _permissionGrants(Object? value) {
  if (value is! List) {
    throw const PermissionFlowValidationException('grants must be a list');
  }
  return value.map((item) {
    final json = _objectMap(item);
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
      createdAt: _requiredUtcValue(json['createdAt'], 'createdAt'),
      revokedAt: _optionalUtc(json['revokedAt'], 'revokedAt'),
      version: json['version'] as int? ?? 1,
    );
  }).toList(growable: false);
}

List<RelationshipCategoryGrant> _relationshipGrants(Object? value) {
  if (value is! List) {
    throw const PermissionFlowValidationException(
      'relationshipGrants must be a list',
    );
  }
  return value.map((item) {
    final json = _objectMap(item);
    final capabilities = _stringSet(json['capabilities'])
        .map((name) => _enumByName(
              RelationshipCapability.values,
              name,
              'relationshipCapability',
            ))
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
      createdAt: _requiredUtcValue(json['createdAt'], 'createdAt'),
      validUntil: _optionalUtc(json['validUntil'], 'validUntil'),
      revokedAt: _optionalUtc(json['revokedAt'], 'revokedAt'),
      version: json['version'] as int? ?? 1,
    );
  }).toList(growable: false);
}

Map<String, int> _intMap(Object? value) {
  final source = _objectMap(value);
  return source.map((key, item) {
    if (item is! int) {
      throw const PermissionFlowValidationException(
        'Coverage values must be integers',
      );
    }
    return MapEntry(key, item);
  });
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((item) => item.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
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
