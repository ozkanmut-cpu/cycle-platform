import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support/partner_journey_models.dart';

const int _seed = 20260918;
final DateTime _virtualNow = DateTime.utc(2026, 9, 18, 9);

PartnerJourneyScenario _scenario({
  String id = 'journey-a',
  String fixtureId = 'RP-001',
  PartnerJourneyFamily family = PartnerJourneyFamily.partnerHomeNavigation,
  List<String> actions = const <String>['open-home'],
  List<String> assertions = const <String>['home-visible'],
}) =>
    PartnerJourneyScenario(
      id: id,
      schemaVersion: 1,
      seed: _seed,
      virtualNow: _virtualNow,
      fixtureId: fixtureId,
      locale: 'en',
      family: family,
      actions: actions,
      assertions: assertions,
    );

PartnerJourneyResult _result(
  String id, {
  String fixtureId = 'RP-001',
  PartnerJourneyFamily family = PartnerJourneyFamily.partnerHomeNavigation,
  Set<String>? coverageLabels,
}) =>
    PartnerJourneyResult(
      scenario: _scenario(id: id, fixtureId: fixtureId, family: family),
      observation: PartnerJourneyObservation(
        surfaceReached: 'now',
        visibleAssertionIds: <String>['home-visible'],
        actionCount: 1,
      ),
      findings: const <PartnerJourneyFinding>[],
      coverageLabels:
          coverageLabels ?? const <String>{'home:now', 'control:positive'},
    );

List<PartnerJourneyResult> _completeCoverageResults() => <PartnerJourneyResult>[
      _result(
        'pairing',
        family: PartnerJourneyFamily.pairingLifecycle,
        coverageLabels: const <String>{
          'pairing:valid',
          'pairing:malformed',
          'pairing:expired',
          'pairing:unsupported-version',
          'pairing:scope-mismatch',
          'pairing:retry-recovery',
          'control:positive',
        },
      ),
      _result(
        'home',
        family: PartnerJourneyFamily.partnerHomeNavigation,
        coverageLabels: const <String>{
          'home:unpaired-negative',
          'home:now',
          'home:us',
          'home:surprise',
          'home:shared-health',
          'control:negative',
        },
      ),
      _result(
        'visibility',
        fixtureId: 'RP-002',
        family: PartnerJourneyFamily.permissionScopedVisibility,
        coverageLabels: const <String>{
          'visibility:fully-shared',
          'visibility:abstract-shared',
          'visibility:engine-only-hidden',
          'visibility:private-hidden',
          'visibility:wrong-recipient-hidden',
        },
      ),
      _result(
        'notification',
        fixtureId: 'RP-002',
        family: PartnerJourneyFamily.notificationPrivacy,
        coverageLabels: const <String>{
          'notification:generic',
          'notification:category-only',
          'notification:detailed-unlocked',
          'notification:detailed-locked-redacted',
          'notification:no-notify-suppressed',
          'notification:content-capability-suppressed',
        },
      ),
      _result(
        'revocation',
        fixtureId: 'RP-005',
        family: PartnerJourneyFamily.revocationDisconnect,
        coverageLabels: const <String>{
          'revocation:key-rotation',
          'revocation:notifications-stopped',
          'revocation:content-cleared',
          'revocation:unpaired',
        },
      ),
      _result(
        'safety',
        fixtureId: 'RP-005',
        family: PartnerJourneyFamily.relationshipSafetySurface,
        coverageLabels: const <String>{
          'safety:no-consent-inference',
          'safety:no-invented-fallback',
          'safety:read-only',
        },
      ),
    ];

typedef _DetectorCase = ({
  PartnerJourneyObservation observation,
  String category,
  PartnerJourneySeverity severity,
  String reasonCode,
});

void main() {
  group('PartnerJourney models', () {
    test('uses the exact stable enum names', () {
      expect(
        PartnerJourneyFamily.values.map((value) => value.name),
        const <String>[
          'pairingLifecycle',
          'partnerHomeNavigation',
          'permissionScopedVisibility',
          'notificationPrivacy',
          'revocationDisconnect',
          'relationshipSafetySurface',
        ],
      );
      expect(
        PartnerJourneySeverity.values.map((value) => value.name),
        const <String>['none', 's3', 's4'],
      );
    });

    test('scenario rejects malformed stable identifiers and non-UTC time', () {
      expect(
        () => _scenario(id: ''),
        throwsArgumentError,
      );
      expect(
        () => _scenario(actions: const <String>['open-home', 'open-home']),
        throwsArgumentError,
      );
      expect(
        () => _scenario(
          assertions: const <String>['home-visible', 'home-visible'],
        ),
        throwsArgumentError,
      );
      expect(
        () => PartnerJourneyScenario(
          id: 'journey-a',
          schemaVersion: 1,
          seed: _seed,
          virtualNow: DateTime(2026, 9, 18, 9),
          fixtureId: 'RP-001',
          locale: 'en',
          family: PartnerJourneyFamily.partnerHomeNavigation,
          actions: const <String>['open-home'],
          assertions: const <String>['home-visible'],
        ),
        throwsArgumentError,
      );
    });

    test('scenario JSON round-trips UTC values and ordered actions', () {
      final scenario = PartnerJourneyScenario(
        id: 'journey-a',
        schemaVersion: 1,
        seed: _seed,
        virtualNow: _virtualNow,
        fixtureId: 'RP-001',
        locale: 'en',
        family: PartnerJourneyFamily.partnerHomeNavigation,
        actions: const <String>['open-us', 'open-now'],
        assertions: const <String>['z-assertion', 'a-assertion'],
        expectedRecoveryAffordances: const <String>['retry-pairing'],
        riskTags: const <String>['privacy'],
      );
      final restored = PartnerJourneyScenario.fromJson(
        Map<String, Object?>.from(
          jsonDecode(jsonEncode(scenario.toJson())) as Map<Object?, Object?>,
        ),
      );

      expect(restored.toJson(), scenario.toJson());
      expect(scenario.toJson()['virtualNow'], '2026-09-18T09:00:00.000Z');
      expect(
        scenario.toJson()['actions'],
        const <String>['open-us', 'open-now'],
      );
      expect(
        scenario.toJson()['assertions'],
        const <String>['a-assertion', 'z-assertion'],
      );
    });

    test('observation owns collection inputs for canonical evidence', () {
      final visible = <String>['visible-a'];
      final absent = <String>['absent-a'];
      final cards = <String>['card-a'];
      final observation = PartnerJourneyObservation(
        visibleAssertionIds: visible,
        forbiddenMarkerAbsenceAssertionIds: absent,
        cardSummaries: cards,
      );
      final before = jsonEncode(observation.toJson());

      visible.add('visible-b');
      absent.add('absent-b');
      cards.add('card-b');

      expect(jsonEncode(observation.toJson()), before);
      expect(() => observation.visibleAssertionIds.add('x'),
          throwsUnsupportedError);
      expect(
        () => observation.forbiddenMarkerAbsenceAssertionIds.add('x'),
        throwsUnsupportedError,
      );
      expect(() => observation.cardSummaries.add('x'), throwsUnsupportedError);
    });

    test('finding owns recursively canonical diagnostics', () {
      final nested = <String, Object?>{'zeta': 2, 'alpha': 1};
      final diagnostics = <String, Object?>{
        'zeta': nested,
        'alpha': <Object?>['zulu', 'alpha'],
      };
      final finding = PartnerJourneyFinding(
        category: 'production_ui_mismatch',
        severity: PartnerJourneySeverity.s3,
        journeyId: 'journey-a',
        assertionId: 'home-visible',
        reasonCode: 'production_ui_mismatch',
        diagnostics: diagnostics,
      );
      final before = jsonEncode(finding.toJson());

      nested['beta'] = 3;
      diagnostics['beta'] = 'beta';

      expect(jsonEncode(finding.toJson()), before);
      expect(finding.toJson()['diagnostics'], <String, Object?>{
        'alpha': <Object?>['alpha', 'zulu'],
        'zeta': <String, Object?>{'alpha': 1, 'zeta': 2},
      });
      expect(() => finding.diagnostics['x'] = 'x', throwsUnsupportedError);
    });

    test('finding rejects hostile noncanonical diagnostics', () {
      PartnerJourneyFinding finding(Object? value) => PartnerJourneyFinding(
            category: 'production_ui_mismatch',
            severity: PartnerJourneySeverity.s3,
            journeyId: 'journey-a',
            assertionId: 'home-visible',
            reasonCode: 'production_ui_mismatch',
            diagnostics: <String, Object?>{'detail': value},
          );

      expect(() => finding('/tmp/host/secret'), throwsArgumentError);
      expect(() => finding(StateError('framework exception')),
          throwsArgumentError);
      expect(() => finding(Object()), throwsArgumentError);
      expect(
        () => finding('550e8400-e29b-41d4-a716-446655440000'),
        throwsArgumentError,
      );
    });
  });

  group('PartnerJourneyDetector', () {
    test('maps every S4 and S3 contract finding exactly', () {
      final cases = <_DetectorCase>[
        (
          observation: PartnerJourneyObservation(
            unpairedSensitiveContentExposed: true,
          ),
          category: 'unpaired_sensitive_content_exposed',
          severity: PartnerJourneySeverity.s4,
          reasonCode: 'unpaired_sensitive_content_exposed',
        ),
        (
          observation: PartnerJourneyObservation(
            lockedNotificationDetailExposed: true,
          ),
          category: 'locked_notification_detail_exposed',
          severity: PartnerJourneySeverity.s4,
          reasonCode: 'locked_notification_detail_exposed',
        ),
        (
          observation: PartnerJourneyObservation(revokedContentRetained: true),
          category: 'revoked_content_retained',
          severity: PartnerJourneySeverity.s4,
          reasonCode: 'revoked_content_retained',
        ),
        (
          observation: PartnerJourneyObservation(
            notificationSentWithoutPermission: true,
          ),
          category: 'notification_sent_without_permission',
          severity: PartnerJourneySeverity.s4,
          reasonCode: 'notification_sent_without_permission',
        ),
        (
          observation: PartnerJourneyObservation(permissionScopeWidened: true),
          category: 'permission_scope_widened',
          severity: PartnerJourneySeverity.s4,
          reasonCode: 'permission_scope_widened',
        ),
        (
          observation: PartnerJourneyObservation(
            pairingInvalidPayloadAccepted: true,
          ),
          category: 'pairing_invalid_payload_accepted',
          severity: PartnerJourneySeverity.s4,
          reasonCode: 'pairing_invalid_payload_accepted',
        ),
        (
          observation: PartnerJourneyObservation(
            pairingScopeMismatchAccepted: true,
          ),
          category: 'pairing_scope_mismatch_accepted',
          severity: PartnerJourneySeverity.s4,
          reasonCode: 'pairing_scope_mismatch_accepted',
        ),
        (
          observation: PartnerJourneyObservation(recipientKeyNotRotated: true),
          category: 'recipient_key_not_rotated',
          severity: PartnerJourneySeverity.s4,
          reasonCode: 'recipient_key_not_rotated',
        ),
        (
          observation: PartnerJourneyObservation(
            consentInferredFromSensitiveData: true,
          ),
          category: 'consent_inferred_from_sensitive_data',
          severity: PartnerJourneySeverity.s4,
          reasonCode: 'consent_inferred_from_sensitive_data',
        ),
        (
          observation: PartnerJourneyObservation(coreJourneyBlocked: true),
          category: 'core_journey_blocked',
          severity: PartnerJourneySeverity.s3,
          reasonCode: 'core_journey_blocked',
        ),
        (
          observation:
              PartnerJourneyObservation(recoveryAffordanceMissing: true),
          category: 'recovery_affordance_missing',
          severity: PartnerJourneySeverity.s3,
          reasonCode: 'recovery_affordance_missing',
        ),
        (
          observation: PartnerJourneyObservation(partnerTabUnreachable: true),
          category: 'partner_tab_unreachable',
          severity: PartnerJourneySeverity.s3,
          reasonCode: 'partner_tab_unreachable',
        ),
        (
          observation: PartnerJourneyObservation(productionUiMismatch: true),
          category: 'production_ui_mismatch',
          severity: PartnerJourneySeverity.s3,
          reasonCode: 'production_ui_mismatch',
        ),
        (
          observation: PartnerJourneyObservation(disconnectIncomplete: true),
          category: 'disconnect_incomplete',
          severity: PartnerJourneySeverity.s3,
          reasonCode: 'disconnect_incomplete',
        ),
        (
          observation: PartnerJourneyObservation(
            notificationPreviewMismatch: true,
          ),
          category: 'notification_preview_mismatch',
          severity: PartnerJourneySeverity.s3,
          reasonCode: 'notification_preview_mismatch',
        ),
        (
          observation: PartnerJourneyObservation(
            malformedReasonCode: 'duplicate-action-id',
          ),
          category: 'malformed_input',
          severity: PartnerJourneySeverity.s3,
          reasonCode: 'duplicate-action-id',
        ),
        (
          observation: PartnerJourneyObservation(
            determinismMismatch: true,
          ),
          category: 'determinism_mismatch',
          severity: PartnerJourneySeverity.s3,
          reasonCode: 'determinism_mismatch',
        ),
      ];

      for (final testCase in cases) {
        final result = PartnerJourneyDetector().evaluate(
          scenario: _scenario(),
          observation: testCase.observation,
          coverageLabels: const <String>{'control:negative'},
        );
        final finding = result.findings.singleWhere(
          (finding) => finding.category == testCase.category,
        );
        expect(finding.severity, testCase.severity);
        expect(finding.reasonCode, testCase.reasonCode);
        expect(result.passed, isFalse);
      }
    });

    test('soft metrics do not produce findings', () {
      final result = PartnerJourneyDetector().evaluate(
        scenario: _scenario(),
        observation: PartnerJourneyObservation(
          visibleAssertionIds: const <String>['home-visible'],
          actionCount: 99,
          navigationCount: 99,
          recoveryCount: 99,
        ),
        coverageLabels: const <String>{'control:positive'},
      );

      expect(result.findings, isEmpty);
      expect(result.passed, isTrue);
    });

    test('fails when a required scenario assertion was not observed', () {
      final result = PartnerJourneyDetector().evaluate(
        scenario: _scenario(
          assertions: const <String>['home-visible', 'read-only-visible'],
        ),
        observation: PartnerJourneyObservation(
          visibleAssertionIds: const <String>['home-visible'],
        ),
        coverageLabels: const <String>{'home:now'},
      );

      expect(result.passed, isFalse);
      expect(result.findings, hasLength(1));
      expect(result.findings.single.category, 'assertion_missing');
      expect(result.findings.single.severity, PartnerJourneySeverity.s3);
      expect(result.findings.single.assertionId, 'read-only-visible');
      expect(result.findings.single.reasonCode,
          'assertion_missing:read-only-visible');
    });

    test('S3 fallback findings are suppressed by an S4 exposure', () {
      final result = PartnerJourneyDetector().evaluate(
        scenario: _scenario(),
        observation: PartnerJourneyObservation(
          visibleAssertionIds: const <String>['home-visible'],
          revokedContentRetained: true,
          disconnectIncomplete: true,
          notificationPreviewMismatch: true,
        ),
        coverageLabels: const <String>{'home:now'},
      );

      expect(result.findings.map((finding) => finding.category), <String>[
        'revoked_content_retained',
      ]);
    });
  });

  group('PartnerJourneyReportBuilder', () {
    test('stably sorts results and canonical JSON round-trips', () {
      final builder = PartnerJourneyReportBuilder(
        seed: _seed,
        virtualNow: _virtualNow,
      );
      final report = builder.build(<PartnerJourneyResult>[
        _result('journey-b'),
        _result('journey-a'),
      ]);
      final json = canonicalPartnerJourneyJson(report);
      final restored = PartnerJourneyReport.fromJson(
        Map<String, Object?>.from(
          jsonDecode(json) as Map<Object?, Object?>,
        ),
      );

      expect(report.results.map((result) => result.scenario.id), <String>[
        'journey-a',
        'journey-b',
      ]);
      expect(canonicalPartnerJourneyJson(restored), json);
      expect(report.syntheticEvidenceOnly, isTrue);
      expect(
        canonicalPartnerJourneyJson(report),
        canonicalPartnerJourneyJson(report),
      );
    });

    test('emits a sorted S3 finding for every missing coverage label', () {
      final report = PartnerJourneyReportBuilder(
        seed: _seed,
        virtualNow: _virtualNow,
      ).build(<PartnerJourneyResult>[
        _result(
          'journey-a',
          coverageLabels: const <String>{'control:positive'},
        ),
      ]);
      final expected = report.coverage.missingLabels
          .map((label) => 'coverage_gap:$label')
          .toList();
      final gaps = report.findings
          .where((finding) => finding.category == 'coverage_gap')
          .toList();

      expect(gaps.map((finding) => finding.reasonCode), expected);
      expect(
        gaps.every((finding) => finding.severity == PartnerJourneySeverity.s3),
        isTrue,
      );
      expect(report.coverage.missingLabels, isNotEmpty);
      expect(report.passed, isFalse);
    });

    test('coverage labels must match the executed scenario family', () {
      expect(
        () => _result(
          'bad-coverage',
          coverageLabels: const <String>{'notification:generic'},
        ),
        throwsArgumentError,
      );
      expect(
        () => _result(
          'bad-fixture',
          coverageLabels: const <String>{'fixture:RP-005'},
        ),
        throwsArgumentError,
      );
    });

    test('has all 40 verbatim mandatory coverage labels', () {
      expect(mandatoryPartnerJourneyCoverageLabels, const <String>{
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
      });
      expect(mandatoryPartnerJourneyCoverageLabels, hasLength(40));

      final report = PartnerJourneyReportBuilder(
        seed: _seed,
        virtualNow: _virtualNow,
      ).build(_completeCoverageResults());
      expect(report.coverage.missingLabels, isEmpty);
      expect(report.passed, isTrue);
      expect(report.results.map((result) => result.scenario.family).toSet(),
          PartnerJourneyFamily.values.toSet());
    });
  });
}
