import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  _genericAttackTests();
  _relationshipAttackTests();
  _revocationRelayAttackTests();
  _coverageAttackTests();
  _privacyAttackSmokeTests();
  group('privacy attack core model', () {
    test('scenario round-trips and requires UTC validated identity', () {
      final scenario = _scenario();

      expect(
        PrivacyAttackScenario.fromJson(scenario.toJson()).toJson(),
        scenario.toJson(),
      );
      expect(
        () => _scenario(at: DateTime(2026, 9, 16, 12)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => _scenario(sourceControlId: '  '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('denyAuthority passes denial and detects fail-open as S4', () async {
      final scenario = _scenario();
      final suite = const PrivacyAttackSuite();

      final contained = await suite.evaluate(
        seed: 20260916,
        scenarios: <PrivacyAttackScenario>[scenario],
        observer:
            const _FixedObserver(PrivacyAttackObservation(allowed: false)),
      );
      expect(contained.passed, isTrue);
      expect(contained.results.single.passed, isTrue);
      expect(contained.results.single.severity, InvariantSeverity.s4);

      final breached = await suite.evaluate(
        seed: 20260916,
        scenarios: <PrivacyAttackScenario>[scenario],
        observer: const _FixedObserver(PrivacyAttackObservation(allowed: true)),
      );
      expect(breached.passed, isFalse);
      expect(breached.results.single.passed, isFalse);
      expect(breached.results.single.severity, InvariantSeverity.s4);
      expect(breached.results.single.findingCategory, 'identity_scope_escape');
    });

    test('report canonicalizes result ordering and JSON round-trip', () async {
      final suite = const PrivacyAttackSuite();
      final report = await suite.evaluate(
        seed: 20260916,
        scenarios: <PrivacyAttackScenario>[
          _scenario(id: 'z-case'),
          _scenario(id: 'a-case'),
        ],
        observer:
            const _FixedObserver(PrivacyAttackObservation(allowed: false)),
      );

      expect(report.results.map((item) => item.scenarioId),
          <String>['a-case', 'z-case']);
      expect(
        PrivacyAttackReport.fromJson(report.toJson()).toNormalizedJson(),
        report.toNormalizedJson(),
      );
      expect(report.syntheticEvidenceOnly, isTrue);
    });
  });
}

PrivacyAttackScenario _scenario({
  String id = 'attack-wrong-recipient',
  String sourceControlId = 'control-view',
  DateTime? at,
}) {
  final mutation = PrivacyAttackMutation(
    id: 'mut-wrong-recipient',
    family: PrivacyAttackFamily.identitySubstitution,
    sourceControlId: sourceControlId,
    dimensions: const <String>{'recipient'},
    before: const <String, Object?>{'recipientId': 'partner-1'},
    after: const <String, Object?>{'recipientId': 'partner-2'},
    paired: false,
  );
  return PrivacyAttackScenario(
    id: id,
    sourceControlId: sourceControlId,
    schemaVersion: privacyAttackSchemaVersion,
    seed: 20260916,
    at: at ?? DateTime.utc(2026, 9, 16, 12),
    ownerId: 'patient-1',
    intendedRecipientId: 'partner-1',
    attemptedRecipientId: 'partner-2',
    family: PrivacyAttackFamily.identitySubstitution,
    targetSurface: 'genericPermission',
    mutation: mutation,
    containmentContract: PrivacyContainmentContract.denyAuthority,
    riskTags: const <String>{'identity', 'recipient', 'phase9Reuse'},
    payload: const <String, Object?>{},
    adversarial: true,
  );
}

class _FixedObserver extends PrivacyAttackObserver {
  const _FixedObserver(this.observation);

  final PrivacyAttackObservation observation;

  @override
  Future<PrivacyAttackObservation> observe(
          PrivacyAttackScenario scenario) async =>
      observation;
}

class _BreachObserver extends PrivacyAttackObserver {
  const _BreachObserver();

  @override
  Future<PrivacyAttackObservation> observe(
      PrivacyAttackScenario scenario) async {
    return switch (scenario.containmentContract) {
      PrivacyContainmentContract.allowAuthority =>
        const PrivacyAttackObservation(allowed: false),
      PrivacyContainmentContract.denyAuthority =>
        const PrivacyAttackObservation(allowed: true),
      PrivacyContainmentContract.allowProjection =>
        const PrivacyAttackObservation(projected: false),
      PrivacyContainmentContract.denyProjection =>
        const PrivacyAttackObservation(projected: true),
      PrivacyContainmentContract.allowRawExposure =>
        const PrivacyAttackObservation(rawValueExposed: false),
      PrivacyContainmentContract.noRawExposure =>
        const PrivacyAttackObservation(rawValueExposed: true),
      PrivacyContainmentContract.emitNotification =>
        const PrivacyAttackObservation(notificationEmitted: false),
      PrivacyContainmentContract.redactOrSuppressNotification =>
        const PrivacyAttackObservation(
            notificationEmitted: true, notificationRedacted: false),
      PrivacyContainmentContract.requireKeyRotation =>
        const PrivacyAttackObservation(keyRotated: false),
      PrivacyContainmentContract.rejectStaleKey =>
        const PrivacyAttackObservation(staleKeyActive: true),
      PrivacyContainmentContract.allowRelayDecrypt =>
        const PrivacyAttackObservation(relayDecryptAccepted: false),
      PrivacyContainmentContract.rejectRelayDecrypt =>
        const PrivacyAttackObservation(relayDecryptAccepted: true),
      PrivacyContainmentContract.rejectRelayIntegrityTamper =>
        const PrivacyAttackObservation(relayIntegrityAccepted: true),
    };
  }
}

class _ThrowingObserver extends PrivacyAttackObserver {
  const _ThrowingObserver();

  @override
  Future<PrivacyAttackObservation> observe(
      PrivacyAttackScenario scenario) async {
    throw const FormatException('malformed fixture');
  }
}

void _genericAttackTests() {
  group('privacy attack generator and generic production attacks', () {
    test('same seed yields stable A-D controls and mutations', () {
      final first = const PrivacyAttackGenerator().generateCanonical(20260916);
      final second = const PrivacyAttackGenerator().generateCanonical(20260916);
      final ids = first.map((item) => item.id).toSet();

      expect(
        first.map((e) => e.toJson()).toList(),
        second.map((e) => e.toJson()).toList(),
      );
      expect(
        first.where((e) => e.adversarial).every(
              (e) => e.sourceControlId.isNotEmpty,
            ),
        isTrue,
      );
      expect(
        ids,
        containsAll(<String>{
          'control-view',
          'attack-wrong-owner',
          'attack-wrong-recipient',
          'attack-view-to-notify',
          'attack-view-to-backup',
          'attack-view-to-export',
          'attack-notify-to-view',
          'attack-backup-to-view',
          'attack-export-to-view',
          'control-scope',
          'attack-wrong-category',
          'attack-wrong-field',
          'attack-wrong-purpose',
          'control-at-activation',
          'attack-before-activation',
          'attack-exact-expiry',
          'attack-exact-revocation',
          'attack-after-revocation',
          'attack-before-data-from',
          'control-at-data-from',
          'control-at-data-until',
          'attack-after-data-until',
          'control-share-view',
          'attack-share-view-to-notify',
        }),
      );
    });

    test('production engines contain every generated A-D privacy attack',
        () async {
      final scenarios =
          const PrivacyAttackGenerator().generateCanonical(20260916).where(
                (item) => <PrivacyAttackFamily>{
                  PrivacyAttackFamily.identitySubstitution,
                  PrivacyAttackFamily.actionEscalation,
                  PrivacyAttackFamily.scopeSubstitution,
                  PrivacyAttackFamily.temporalReplay,
                }.contains(item.family),
              );
      final report = await const PrivacyAttackSuite().evaluate(
        seed: 20260916,
        scenarios: scenarios,
        observer: const ProductionPrivacyAttackObserver(),
      );

      expect(report.results, isNotEmpty);
      expect(report.results.where((item) => !item.passed), isEmpty);
      expect(report.coverage.malformedInputFailures, 0);
    });
  });
}

void _relationshipAttackTests() {
  group('privacy attack relationship production attacks', () {
    test('canonical generator includes E-H attack families', () {
      final scenarios =
          const PrivacyAttackGenerator().generateCanonical(20260916);
      final ids = scenarios.map((item) => item.id).toSet();

      expect(
          ids,
          containsAll(<String>{
            'control-composed-view',
            'attack-composed-mixed-recipient',
            'attack-composed-wrong-category',
            'attack-composed-missing-generic',
            'control-relationship-view',
            'attack-view-to-intelligence',
            'attack-view-to-playful',
            'attack-view-to-intimacy',
            'attack-one-direction-intimacy-reverse',
            'control-projection-fully-shared',
            'attack-projection-private',
            'attack-projection-engine-only',
            'attack-projection-abstract-shared',
            'control-notification-generic',
            'control-notification-category-only',
            'control-notification-detailed-unlocked',
            'attack-notification-detailed-locked',
            'attack-notification-missing-playful',
            'attack-notification-missing-intimacy',
          }));
    });

    test('production relationship surfaces contain E-H attacks', () async {
      final scenarios = const PrivacyAttackGenerator()
          .generateCanonical(20260916)
          .where((item) => <PrivacyAttackFamily>{
                PrivacyAttackFamily.composedGrantConfusion,
                PrivacyAttackFamily.relationshipCapabilityEscalation,
                PrivacyAttackFamily.visibilityExfiltration,
                PrivacyAttackFamily.notificationLeakage,
              }.contains(item.family));
      final report = await const PrivacyAttackSuite().evaluate(
        seed: 20260916,
        scenarios: scenarios,
        observer: const ProductionPrivacyAttackObserver(),
      );
      final byId = <String, PrivacyAttackResult>{
        for (final result in report.results) result.scenarioId: result,
      };

      expect(report.results, isNotEmpty);
      expect(report.results.where((item) => !item.passed), isEmpty);
      expect(
          byId['control-projection-fully-shared']!.observation.rawValueExposed,
          isTrue);
      expect(byId['attack-projection-engine-only']!.observation.rawValueExposed,
          isFalse);
      expect(
          byId['control-notification-detailed-unlocked']!
              .observation
              .notificationRedacted,
          isFalse);
      expect(
          byId['attack-notification-detailed-locked']!
              .observation
              .notificationRedacted,
          isTrue);
      expect(
          byId['attack-notification-missing-intimacy']!
              .observation
              .notificationEmitted,
          isFalse);
      expect(report.coverage.malformedInputFailures, 0);
    });
  });
}

void _revocationRelayAttackTests() {
  group('privacy attack revocation key and relay production attacks', () {
    test('canonical generator includes I-J attack families', () {
      final ids = const PrivacyAttackGenerator()
          .generateCanonical(20260916)
          .map((item) => item.id)
          .toSet();
      expect(
        ids,
        containsAll(<String>{
          'control-revocation-key-rotation',
          'attack-stale-key-replay',
          'attack-revoked-grant-reuse',
          'control-relay-correct-recipient',
          'attack-relay-wrong-recipient',
          'attack-relay-associated-data-tamper',
          'attack-relay-ciphertext-tamper',
        }),
      );
    });

    test('production revocation and relay primitives contain I-J attacks',
        () async {
      final scenarios = const PrivacyAttackGenerator()
          .generateCanonical(20260916)
          .where((item) => <PrivacyAttackFamily>{
                PrivacyAttackFamily.revocationAndKeyReplay,
                PrivacyAttackFamily.relayRecipientBinding,
              }.contains(item.family));
      final report = await const PrivacyAttackSuite().evaluate(
        seed: 20260916,
        scenarios: scenarios,
        observer: const ProductionPrivacyAttackObserver(),
      );
      final byId = <String, PrivacyAttackResult>{
        for (final result in report.results) result.scenarioId: result,
      };

      expect(report.results, isNotEmpty);
      expect(report.results.where((item) => !item.passed), isEmpty);
      expect(
        byId['control-revocation-key-rotation']!.observation.keyRotated,
        isTrue,
      );
      expect(
        byId['control-revocation-key-rotation']!
            .observation
            .notificationsStopped,
        isTrue,
      );
      expect(
        byId['control-revocation-key-rotation']!.observation.exportsInvalidated,
        isTrue,
      );
      expect(
        byId['attack-stale-key-replay']!.observation.staleKeyActive,
        isFalse,
      );
      expect(
        byId['control-relay-correct-recipient']!
            .observation
            .relayDecryptAccepted,
        isTrue,
      );
      expect(
        byId['attack-relay-wrong-recipient']!.observation.relayDecryptAccepted,
        isFalse,
      );
      expect(
        byId['attack-relay-associated-data-tamper']!
            .observation
            .relayIntegrityAccepted,
        isFalse,
      );
      expect(
        byId['attack-relay-ciphertext-tamper']!
            .observation
            .relayIntegrityAccepted,
        isFalse,
      );
      expect(report.coverage.malformedInputFailures, 0);
    });
  });
}

void _coverageAttackTests() {
  group('privacy attack canonical coverage and detector', () {
    test('canonical matrix covers every family and mandatory gate passes',
        () async {
      final scenarios = buildCanonicalPrivacyAttackScenarios(20260916);
      expect(
        scenarios.map((item) => item.family).toSet(),
        containsAll(PrivacyAttackFamily.values),
      );
      final report = await const PrivacyAttackSuite().evaluate(
        seed: 20260916,
        scenarios: scenarios,
        observer: const ProductionPrivacyAttackObserver(),
        requireMandatoryCoverage: true,
      );
      expect(report.passed, isTrue);
      expect(report.coverage.malformedInputFailures, 0);
      expect(report.coverage.safeControls, greaterThan(0));
      expect(report.coverage.adversarialScenarios, greaterThan(0));
    });

    test('removing one family creates deterministic coverage_gap', () async {
      final scenarios = buildCanonicalPrivacyAttackScenarios(20260916)
          .where((item) =>
              item.family != PrivacyAttackFamily.relayRecipientBinding)
          .toList();
      final report = await const PrivacyAttackSuite().evaluate(
        seed: 20260916,
        scenarios: scenarios,
        observer: const ProductionPrivacyAttackObserver(),
        requireMandatoryCoverage: true,
      );
      final gaps = report.results
          .where((item) => item.findingCategory == 'coverage_gap')
          .toList();
      expect(report.passed, isFalse);
      expect(gaps, hasLength(1));
      expect(gaps.single.reasonCode, contains('family:relayRecipientBinding'));
    });

    test('malformed observer input fails closed as S4 malformed_input',
        () async {
      final scenario = buildCanonicalPrivacyAttackScenarios(20260916).first;
      final report = await const PrivacyAttackSuite().evaluate(
        seed: 20260916,
        scenarios: <PrivacyAttackScenario>[scenario],
        observer: const _ThrowingObserver(),
      );
      expect(report.passed, isFalse);
      expect(report.coverage.malformedInputFailures, 1);
      expect(report.results.single.findingCategory, 'malformed_input');
      expect(report.results.single.severity, InvariantSeverity.s4);
    });

    test('detector self-test exposes every stable S4 privacy category',
        () async {
      final canonical = buildCanonicalPrivacyAttackScenarios(20260916);
      const ids = <String>{
        'attack-wrong-recipient',
        'attack-view-to-export',
        'attack-wrong-purpose',
        'attack-exact-revocation',
        'attack-composed-mixed-recipient',
        'attack-view-to-intimacy',
        'attack-projection-engine-only',
        'attack-notification-detailed-locked',
        'attack-revoked-grant-reuse',
        'attack-stale-key-replay',
        'attack-relay-wrong-recipient',
        'attack-relay-associated-data-tamper',
      };
      final scenarios = canonical.where((item) => ids.contains(item.id));
      final report = await const PrivacyAttackSuite().evaluate(
        seed: 20260916,
        scenarios: scenarios,
        observer: const _BreachObserver(),
      );
      expect(report.results.every((item) => !item.passed), isTrue);
      expect(
        report.results.map((item) => item.findingCategory).toSet(),
        containsAll(<String>{
          'identity_scope_escape',
          'action_escalation',
          'scope_escape',
          'temporal_replay_escape',
          'composed_gate_bypass',
          'relationship_capability_escalation',
          'visibility_exfiltration',
          'notification_privacy_violation',
          'revocation_escape',
          'stale_key_escape',
          'relay_recipient_bypass',
          'relay_integrity_violation',
        }),
      );
    });

    test('permuted input ordering produces byte-identical report', () async {
      final scenarios = buildCanonicalPrivacyAttackScenarios(20260916);
      final forward = await const PrivacyAttackSuite().evaluate(
        seed: 20260916,
        scenarios: scenarios,
        observer: const ProductionPrivacyAttackObserver(),
        requireMandatoryCoverage: true,
      );
      final reverse = await const PrivacyAttackSuite().evaluate(
        seed: 20260916,
        scenarios: scenarios.reversed,
        observer: const ProductionPrivacyAttackObserver(),
        requireMandatoryCoverage: true,
      );
      expect(reverse.toNormalizedJson(), forward.toNormalizedJson());
    });
  });
}

void _privacyAttackSmokeTests() {
  group('privacy attack production smoke', () {
    test('production smoke is deterministic and synthetic only', () async {
      final first = await runProductionPrivacyAttackSmoke(20260916);
      final second = await runProductionPrivacyAttackSmoke(20260916);

      expect(first.passed, isTrue);
      expect(first.syntheticEvidenceOnly, isTrue);
      expect(first.coverage.malformedInputFailures, 0);
      expect(first.coverage.failedScenarios, 0);
      expect(first.toNormalizedJson(), second.toNormalizedJson());
      expect(
        first.coverage.families.keys.toSet(),
        containsAll(PrivacyAttackFamily.values.map((item) => item.name)),
      );
    });
  });
}
