import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  group('permission flow core model', () {
    test('scenario rejects blank id, non-UTC time, and unsupported schema', () {
      PermissionFlowScenario build({
        String id = 'case-1',
        int schemaVersion = permissionFlowSchemaVersion,
        DateTime? at,
      }) =>
          PermissionFlowScenario(
            id: id,
            schemaVersion: schemaVersion,
            seed: 20260916,
            at: at ?? DateTime.utc(2026, 9, 16),
            ownerId: 'patient-1',
            recipientId: 'partner-1',
            kind: PermissionFlowScenarioKind.generic,
            expectation: PermissionFlowExpectation.mustDeny,
            violationReason: 'default_deny_bypass',
          );

      expect(() => build(id: '  '),
          throwsA(isA<PermissionFlowValidationException>()));
      expect(
        () => build(at: DateTime(2026, 9, 16)),
        throwsA(isA<PermissionFlowValidationException>()),
      );
      expect(
        () => build(schemaVersion: permissionFlowSchemaVersion + 1),
        throwsA(isA<PermissionFlowValidationException>()),
      );
    });

    test('all permission-flow results serialize as S4', () {
      final result = PermissionFlowResult(
        scenarioId: 'case-1',
        passed: false,
        reasonCode: 'action_escalation',
        evaluatedAt: DateTime.utc(2026, 9, 16),
        evidence: const <String, Object?>{'allowed': true},
      );

      expect(result.severity, InvariantSeverity.s4);
      expect(result.toJson()['severity'], 's4');
    });

    test('report sorts results and round-trips byte-stably', () {
      PermissionFlowResult result(String id) => PermissionFlowResult(
            scenarioId: id,
            passed: true,
            reasonCode: 'allowed',
            evaluatedAt: DateTime.utc(2026, 9, 16),
            evidence: <String, Object?>{
              'z': 1,
              'a': <String, Object?>{'z': 2, 'a': 3},
            },
          );
      final report = PermissionFlowReport(
        seed: 20260916,
        results: <PermissionFlowResult>[result('z-case'), result('a-case')],
        coverage: const PermissionFlowCoverage.empty(),
      );
      final normalized = report.toNormalizedJson();
      final roundTrip = PermissionFlowReport.fromJson(report.toJson());

      expect(report.results.map((item) => item.scenarioId),
          <String>['a-case', 'z-case']);
      expect(roundTrip.toNormalizedJson(), normalized);
      expect(roundTrip.syntheticEvidenceOnly, isTrue);
    });

    test('scenario JSON round-trip preserves coverage metadata', () {
      final scenario = PermissionFlowScenario(
        id: 'case-round-trip',
        schemaVersion: permissionFlowSchemaVersion,
        seed: 20260916,
        at: DateTime.utc(2026, 9, 16, 9),
        ownerId: 'patient-1',
        recipientId: 'partner-1',
        kind: PermissionFlowScenarioKind.projection,
        expectation: PermissionFlowExpectation.mustProjectWithoutRaw,
        violationReason: 'abstract_data_exposed',
        relationshipCapability: 'view',
        visibility: 'abstractShared',
        boundary: 'revocation',
        escalationAttempt: true,
        leakageAttempt: true,
        payload: const <String, Object?>{'value': 'sensitive'},
      );

      expect(
        PermissionFlowScenario.fromJson(scenario.toJson()).toJson(),
        scenario.toJson(),
      );
    });
  });

  group('production permission flow observer', () {
    test('generic permission boundaries are enforced by production engines',
        () {
      final observer = ProductionPermissionFlowObserver();
      final cases = <PermissionFlowScenario, bool>{
        _genericScenario(
            id: 'safe-view',
            expectation: PermissionFlowExpectation.mustAllow): true,
        _genericScenario(
            id: 'wrong-owner',
            ownerId: 'patient-2',
            violationReason: 'actor_scope_escape'): false,
        _genericScenario(
            id: 'wrong-recipient',
            recipientId: 'partner-2',
            violationReason: 'actor_scope_escape'): false,
        _genericScenario(
            id: 'action-escalation',
            action: 'notify',
            violationReason: 'action_escalation',
            escalationAttempt: true): false,
        _genericScenario(
            id: 'category-escape',
            category: 'sleep',
            violationReason: 'category_scope_escape'): false,
        _genericScenario(
            id: 'field-escape',
            field: 'pain',
            grantFields: const <String>['flow'],
            violationReason: 'field_scope_escape'): false,
        _genericScenario(
            id: 'purpose-escape',
            purpose: 'intimacy',
            grantPurposes: const <String>['support'],
            violationReason: 'purpose_scope_escape'): false,
      };

      for (final entry in cases.entries) {
        expect(observer.observe(entry.key).allowed, entry.value,
            reason: entry.key.id);
      }
    });

    test('grant and historical data boundaries use production time semantics',
        () {
      final observer = ProductionPermissionFlowObserver();
      final at = DateTime.utc(2026, 9, 16, 9);
      final cases = <PermissionFlowScenario, bool>{
        _genericScenario(
            id: 'pre-created',
            at: at,
            createdAt: at.add(const Duration(minutes: 1)),
            violationReason: 'grant_time_escape'): false,
        _genericScenario(
            id: 'valid-until-exact',
            at: at,
            validUntil: at,
            violationReason: 'grant_time_escape',
            boundary: 'grantEnd'): false,
        _genericScenario(
            id: 'revoked-exact',
            at: at,
            revokedAt: at,
            violationReason: 'revocation_breach',
            boundary: 'revocation'): false,
        _genericScenario(
            id: 'data-from-exact',
            at: at,
            resourceObservedAt: at,
            dataFrom: at,
            expectation: PermissionFlowExpectation.mustAllow,
            boundary: 'dataFrom'): true,
        _genericScenario(
            id: 'data-until-exact',
            at: at,
            resourceObservedAt: at,
            dataUntil: at,
            expectation: PermissionFlowExpectation.mustAllow,
            boundary: 'dataUntil'): true,
        _genericScenario(
            id: 'before-data-window',
            at: at,
            resourceObservedAt: at.subtract(const Duration(minutes: 1)),
            dataFrom: at,
            violationReason: 'data_window_escape'): false,
        _genericScenario(
            id: 'after-data-window',
            at: at,
            resourceObservedAt: at.add(const Duration(minutes: 1)),
            dataUntil: at,
            violationReason: 'data_window_escape'): false,
      };
      for (final entry in cases.entries) {
        expect(observer.observe(entry.key).allowed, entry.value,
            reason: entry.key.id);
      }
    });

    test('share policy keeps view notify and backup independent', () {
      final observation =
          ProductionPermissionFlowObserver().observe(_shareScenario());
      expect(observation.capabilities, <String, bool>{
        'view': true,
        'notify': false,
        'backup': false,
      });
    });

    test('composed access requires both production gates', () {
      final observer = ProductionPermissionFlowObserver();
      final fixtures = _composedFixtures();
      expect(observer.observe(fixtures['genericOnly']!).allowed, isFalse);
      expect(observer.observe(fixtures['relationshipOnly']!).allowed, isFalse);
      expect(observer.observe(fixtures['both']!).allowed, isTrue);
    });

    test('relationship projection preserves the visibility ceiling', () {
      final observer = ProductionPermissionFlowObserver();
      final fixtures = _projectionFixtures();
      final engineOnly = observer.observe(fixtures['engineOnly']!);
      final abstractShared = observer.observe(fixtures['abstractShared']!);
      final fullyShared = observer.observe(fixtures['fullyShared']!);
      final private = observer.observe(fixtures['private']!);
      expect(engineOnly.visibility, 'engineOnly');
      expect(engineOnly.exposesRawValue, isFalse);
      expect(abstractShared.visibility, 'abstractShared');
      expect(abstractShared.exposesRawValue, isFalse);
      expect(fullyShared.visibility, 'fullyShared');
      expect(fullyShared.exposesRawValue, isTrue);
      expect(private.visibility, 'private');
      expect(private.exposesRawValue, isFalse);
    });
  });

  group('canonical permission flow smoke', () {
    test('is deterministic and covers every required contract dimension', () {
      final first = runProductionPermissionFlowSmoke(20260916);
      final second = runProductionPermissionFlowSmoke(20260916);

      expect(first.passed, isTrue);
      expect(first.toNormalizedJson(), second.toNormalizedJson());
      expect(
        first.coverage.scenarioKinds.keys,
        containsAll(<String>[
          'generic',
          'sharePolicy',
          'relationship',
          'composedAccess',
          'projection',
        ]),
      );
      expect(first.coverage.actions.keys,
          containsAll(<String>['view', 'notify', 'backup', 'export']));
      expect(
        first.coverage.relationshipCapabilities.keys,
        containsAll(<String>[
          'view',
          'notify',
          'relationshipIntelligence',
          'playful',
          'intimacy',
        ]),
      );
      expect(
        first.coverage.visibilities.keys,
        containsAll(<String>[
          'private',
          'engineOnly',
          'abstractShared',
          'fullyShared',
        ]),
      );
      expect(
        first.coverage.boundaries.keys,
        containsAll(<String>[
          'grantStart',
          'grantEnd',
          'revocation',
          'dataFrom',
          'dataUntil',
        ]),
      );
      expect(first.coverage.escalationAttempts, greaterThan(0));
      expect(first.coverage.leakageAttempts, greaterThan(0));
      expect(first.coverage.malformedInputFailures, 0);
      final scenarios = buildCanonicalPermissionFlowScenarios(20260916);
      final ids = scenarios.map((item) => item.id).toList(growable: false);
      expect(ids.toSet().length, ids.length);
    });

    test('covers no-purpose request against an explicitly purposed grant', () {
      final scenarios = buildCanonicalPermissionFlowScenarios(20260916);
      expect(
        scenarios.map((item) => item.id),
        contains('generic.scope.no-purpose-explicit-grant'),
      );
    });

    test('fully shared projection may safely remain more restrictive', () {
      final scenario = buildCanonicalPermissionFlowScenarios(20260916)
          .singleWhere((item) => item.id == 'projection.full.raw-allowed');
      final result = PermissionFlowSuite(
        observer: const _UnsafeObserver(
          PermissionFlowObservation(
            allowed: true,
            projected: true,
            exposesRawValue: false,
            visibility: 'fullyShared',
          ),
        ),
      ).evaluate(scenario);

      expect(result.passed, isTrue);
    });
  });

  group('permission flow S4 contracts', () {
    test('mustDeny breach becomes S4 with scenario violation reason', () {
      final scenario = _genericScenario(
        id: 'detector-action-escalation',
        action: 'notify',
        violationReason: 'action_escalation',
        escalationAttempt: true,
      );
      final result = PermissionFlowSuite(
        observer:
            const _UnsafeObserver(PermissionFlowObservation(allowed: true)),
      ).evaluate(scenario);

      expect(result.passed, isFalse);
      expect(result.severity, InvariantSeverity.s4);
      expect(result.reasonCode, 'action_escalation');
    });

    test('raw leakage breaches retain exact S4 reason codes', () {
      final fixtures = _projectionFixtures();
      for (final entry in <String, PermissionFlowScenario>{
        'private_data_exposed': fixtures['private']!,
        'engine_only_data_exposed': fixtures['engineOnly']!,
        'abstract_data_exposed': fixtures['abstractShared']!,
      }.entries) {
        final result = PermissionFlowSuite(
          observer: const _UnsafeObserver(
            PermissionFlowObservation(
              allowed: true,
              projected: true,
              exposesRawValue: true,
            ),
          ),
        ).evaluate(entry.value);
        expect(result.passed, isFalse, reason: entry.key);
        expect(result.reasonCode, entry.key, reason: entry.key);
        expect(result.severity, InvariantSeverity.s4, reason: entry.key);
      }
    });

    test('run converts malformed observer input into counted fail-closed S4',
        () {
      final malformed = PermissionFlowScenario(
        id: 'malformed-generic',
        schemaVersion: permissionFlowSchemaVersion,
        seed: 20260916,
        at: DateTime.utc(2026, 9, 16, 9),
        ownerId: 'patient-1',
        recipientId: 'partner-1',
        kind: PermissionFlowScenarioKind.generic,
        expectation: PermissionFlowExpectation.mustDeny,
        violationReason: 'default_deny_bypass',
        payload: const <String, Object?>{},
      );
      final report = PermissionFlowSuite().run(
        seed: 20260916,
        scenarios: <PermissionFlowScenario>[malformed],
      );

      expect(report.passed, isFalse);
      expect(report.results.single.reasonCode, 'malformed_input');
      expect(report.results.single.severity, InvariantSeverity.s4);
      expect(report.coverage.malformedInputFailures, 1);
    });
  });
}

PermissionFlowScenario _genericScenario({
  required String id,
  String ownerId = 'patient-1',
  String recipientId = 'partner-1',
  String action = 'view',
  String category = 'cycle',
  String? field,
  String? purpose,
  List<String> grantActions = const <String>['view'],
  List<String> grantCategories = const <String>['cycle'],
  List<String> grantFields = const <String>[],
  List<String> grantPurposes = const <String>[],
  DateTime? at,
  DateTime? createdAt,
  DateTime? validFrom,
  DateTime? validUntil,
  DateTime? revokedAt,
  DateTime? resourceObservedAt,
  DateTime? dataFrom,
  DateTime? dataUntil,
  PermissionFlowExpectation expectation = PermissionFlowExpectation.mustDeny,
  String violationReason = 'default_deny_bypass',
  String? boundary,
  bool escalationAttempt = false,
}) {
  final evaluatedAt = at ?? DateTime.utc(2026, 9, 16, 9);
  final grantCreatedAt =
      createdAt ?? evaluatedAt.subtract(const Duration(hours: 1));
  final scope = <String, Object?>{
    'categories': grantCategories,
    'fields': grantFields,
    'purposes': grantPurposes,
    if (validFrom != null) 'validFrom': validFrom.toIso8601String(),
    if (validUntil != null) 'validUntil': validUntil.toIso8601String(),
    if (dataFrom != null) 'dataFrom': dataFrom.toIso8601String(),
    if (dataUntil != null) 'dataUntil': dataUntil.toIso8601String(),
  };
  final request = <String, Object?>{
    'action': action,
    'category': category,
    if (field != null) 'field': field,
    if (purpose != null) 'purpose': purpose,
    if (resourceObservedAt != null)
      'resourceObservedAt': resourceObservedAt.toIso8601String(),
  };
  final grant = <String, Object?>{
    'id': 'grant-$id',
    'ownerId': 'patient-1',
    'recipientId': 'partner-1',
    'recipientKind': 'partner',
    'actions': grantActions,
    'scope': scope,
    'createdAt': grantCreatedAt.toIso8601String(),
    if (revokedAt != null) 'revokedAt': revokedAt.toIso8601String(),
    'version': 1,
  };
  return PermissionFlowScenario(
    id: id,
    schemaVersion: permissionFlowSchemaVersion,
    seed: 20260916,
    at: evaluatedAt,
    ownerId: ownerId,
    recipientId: recipientId,
    kind: PermissionFlowScenarioKind.generic,
    expectation: expectation,
    violationReason: violationReason,
    action: action,
    boundary: boundary,
    escalationAttempt: escalationAttempt,
    payload: <String, Object?>{
      'request': request,
      'grants': <Object?>[grant],
    },
  );
}

PermissionFlowScenario _shareScenario() => PermissionFlowScenario(
      id: 'share-view-only',
      schemaVersion: permissionFlowSchemaVersion,
      seed: 20260916,
      at: DateTime.utc(2026, 9, 16, 9),
      ownerId: 'patient-1',
      recipientId: 'partner-1',
      kind: PermissionFlowScenarioKind.sharePolicy,
      expectation: PermissionFlowExpectation.mustAllow,
      violationReason: 'action_escalation',
      action: 'view',
      payload: <String, Object?>{
        'category': 'cycle',
        'grants': <Object?>[
          <String, Object?>{
            'id': 'grant-share-view',
            'ownerId': 'patient-1',
            'recipientId': 'partner-1',
            'recipientKind': 'partner',
            'actions': <String>['view'],
            'scope': <String, Object?>{
              'categories': <String>['cycle'],
            },
            'createdAt': '2026-09-16T08:00:00.000Z',
            'version': 1,
          },
        ],
      },
    );

Map<String, PermissionFlowScenario> _composedFixtures() {
  final at = DateTime.utc(2026, 9, 16, 9);
  final genericGrant = <String, Object?>{
    'id': 'generic-view',
    'ownerId': 'patient-1',
    'recipientId': 'partner-1',
    'recipientKind': 'partner',
    'actions': <String>['view'],
    'scope': <String, Object?>{
      'categories': <String>['cycle']
    },
    'createdAt': '2026-09-16T08:00:00.000Z',
    'version': 1,
  };
  final relationshipGrant = <String, Object?>{
    'id': 'relationship-view',
    'ownerId': 'patient-1',
    'recipientId': 'partner-1',
    'category': 'cycle',
    'capabilities': <String>['view'],
    'visibility': 'fullyShared',
    'createdAt': '2026-09-16T08:00:00.000Z',
    'version': 1,
  };
  PermissionFlowScenario build(
    String id,
    List<Object?> genericGrants,
    List<Object?> relationshipGrants,
    PermissionFlowExpectation expectation,
  ) =>
      PermissionFlowScenario(
        id: id,
        schemaVersion: permissionFlowSchemaVersion,
        seed: 20260916,
        at: at,
        ownerId: 'patient-1',
        recipientId: 'partner-1',
        kind: PermissionFlowScenarioKind.composedAccess,
        expectation: expectation,
        violationReason: 'composed_gate_bypass',
        action: 'view',
        relationshipCapability: 'view',
        escalationAttempt: expectation == PermissionFlowExpectation.mustDeny,
        payload: <String, Object?>{
          'genericCategory': 'cycle',
          'relationshipCategory': 'cycle',
          'genericAction': 'view',
          'relationshipCapability': 'view',
          'genericGrants': genericGrants,
          'relationshipGrants': relationshipGrants,
        },
      );
  return <String, PermissionFlowScenario>{
    'genericOnly': build(
      'composed-generic-only',
      <Object?>[genericGrant],
      const <Object?>[],
      PermissionFlowExpectation.mustDeny,
    ),
    'relationshipOnly': build(
      'composed-relationship-only',
      const <Object?>[],
      <Object?>[relationshipGrant],
      PermissionFlowExpectation.mustDeny,
    ),
    'both': build(
      'composed-both',
      <Object?>[genericGrant],
      <Object?>[relationshipGrant],
      PermissionFlowExpectation.mustAllow,
    ),
  };
}

Map<String, PermissionFlowScenario> _projectionFixtures() {
  PermissionFlowScenario build({
    required String id,
    required String itemVisibility,
    required String grantVisibility,
    required String capability,
    required PermissionFlowExpectation expectation,
    required String violationReason,
  }) =>
      PermissionFlowScenario(
        id: id,
        schemaVersion: permissionFlowSchemaVersion,
        seed: 20260916,
        at: DateTime.utc(2026, 9, 16, 9),
        ownerId: 'patient-1',
        recipientId: 'partner-1',
        kind: PermissionFlowScenarioKind.projection,
        expectation: expectation,
        violationReason: violationReason,
        relationshipCapability: capability,
        visibility: grantVisibility,
        leakageAttempt:
            expectation == PermissionFlowExpectation.mustProjectWithoutRaw,
        payload: <String, Object?>{
          'item': <String, Object?>{
            'category': 'cycle',
            'value': 'sensitive-value',
            'observedAt': '2026-09-16T08:30:00.000Z',
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
              'createdAt': '2026-09-16T08:00:00.000Z',
              'version': 1,
            },
          ],
        },
      );

  return <String, PermissionFlowScenario>{
    'engineOnly': build(
      id: 'projection-engine-only',
      itemVisibility: 'fullyShared',
      grantVisibility: 'engineOnly',
      capability: 'relationshipIntelligence',
      expectation: PermissionFlowExpectation.mustProjectWithoutRaw,
      violationReason: 'engine_only_data_exposed',
    ),
    'abstractShared': build(
      id: 'projection-abstract',
      itemVisibility: 'fullyShared',
      grantVisibility: 'abstractShared',
      capability: 'view',
      expectation: PermissionFlowExpectation.mustProjectWithoutRaw,
      violationReason: 'abstract_data_exposed',
    ),
    'fullyShared': build(
      id: 'projection-full',
      itemVisibility: 'fullyShared',
      grantVisibility: 'fullyShared',
      capability: 'view',
      expectation: PermissionFlowExpectation.mustProject,
      violationReason: 'fully_shared_projection_missing',
    ),
    'private': build(
      id: 'projection-private',
      itemVisibility: 'private',
      grantVisibility: 'engineOnly',
      capability: 'relationshipIntelligence',
      expectation: PermissionFlowExpectation.mustProjectWithoutRaw,
      violationReason: 'private_data_exposed',
    ),
  };
}

class _UnsafeObserver implements PermissionFlowObserver {
  const _UnsafeObserver(this.observation);

  final PermissionFlowObservation observation;

  @override
  PermissionFlowObservation observe(PermissionFlowScenario scenario) =>
      observation;
}
