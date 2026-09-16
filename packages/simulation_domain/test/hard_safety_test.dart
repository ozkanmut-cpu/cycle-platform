import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  group('hard safety core model', () {
    test('case validation rejects blank ids and non-UTC timestamps', () {
      expect(
        () => HardSafetyCase(
          id: ' ',
          invariantId: HardSafetyInvariantId.permissionRevocationBoundary,
          observedAt: DateTime.utc(2026, 9, 16),
          seed: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => HardSafetyCase(
          id: 'case-1',
          invariantId: HardSafetyInvariantId.permissionRevocationBoundary,
          observedAt: DateTime(2026, 9, 16),
          seed: 1,
        ),
        throwsArgumentError,
      );
    });

    test('all hard-safety results serialize as S4', () {
      final result = HardSafetyResult(
        caseId: 'case-1',
        invariantId: HardSafetyInvariantId.aiContextFirewall,
        passed: false,
        reasonCode: 'context_crossed_firewall',
        evaluatedAt: DateTime.utc(2026, 9, 16),
        evidence: const {'modelInvoked': true},
      );
      expect(result.severity, InvariantSeverity.s4);
      expect(result.toJson()['severity'], 's4');
    });

    test('report sorts results and is byte-stable for equal inputs', () {
      final at = DateTime.utc(2026, 9, 16, 4);
      final results = [
        HardSafetyResult(
          caseId: 'z-case',
          invariantId: HardSafetyInvariantId.permissionRevocationBoundary,
          passed: true,
          reasonCode: 'ok',
          evaluatedAt: at,
          evidence: const {'z': 1, 'a': 2},
        ),
        HardSafetyResult(
          caseId: 'a-case',
          invariantId: HardSafetyInvariantId.aiContextFirewall,
          passed: true,
          reasonCode: 'ok',
          evaluatedAt: at,
          evidence: const {'b': 2, 'a': 1},
        ),
      ];
      final first = HardSafetyReport(seed: 77, results: results);
      final second = HardSafetyReport(seed: 77, results: results.reversed);
      expect(second.toNormalizedJson(), first.toNormalizedJson());
      expect(first.passed, isTrue);
      expect(first.coverage.evaluatedCases, 2);
      expect(first.coverage.failedCases, 0);
      expect(first.toJson()['syntheticEvidenceOnly'], isTrue);
    });

    test('report round-trip preserves semantics', () {
      final report = HardSafetyReport(
        seed: 44,
        results: [
          HardSafetyResult(
            caseId: 'case-1',
            invariantId: HardSafetyInvariantId.uncertaintyMissingNotKnown,
            passed: false,
            reasonCode: 'missing_collapsed',
            evaluatedAt: DateTime.utc(2026, 9, 16),
            evidence: const {'actualState': 'known'},
          ),
        ],
      );
      final decoded =
          jsonDecode(report.toNormalizedJson()) as Map<String, Object?>;
      final restored = HardSafetyReport.fromJson(decoded);
      expect(restored.toNormalizedJson(), report.toNormalizedJson());
      expect(restored.passed, isFalse);
      expect(restored.coverage.failedCases, 1);
    });
  });

  group('uncertainty and permission adapters', () {
    final at = DateTime.utc(2026, 9, 16, 5);

    test('oracle-backed uncertainty gates detect all semantic collapses', () {
      final observer = ProductionHardSafetyObserver();
      final suite = HardSafetySuite(observer: observer);
      HardSafetyCase uncertaintyCase(
        String id,
        HardSafetyInvariantId invariant,
        String expected,
        String actual, {
        num? value,
        num? conflictingValue,
        num? actualValue,
      }) =>
          HardSafetyCase(
            id: id,
            invariantId: invariant,
            patientId: 'P-001',
            observedAt: at,
            seed: 99,
            input: {
              'expectedState': expected,
              'actualState': actual,
              if (value != null) 'value': value,
              if (conflictingValue != null)
                'conflictingValue': conflictingValue,
              if (actualValue != null) 'actualValue': actualValue,
            },
          );

      final report = suite.run(seed: 99, cases: [
        uncertaintyCase(
          'missing-safe',
          HardSafetyInvariantId.uncertaintyMissingNotKnown,
          'missing',
          'missing',
        ),
        uncertaintyCase(
          'missing-collapse',
          HardSafetyInvariantId.uncertaintyMissingNotKnown,
          'missing',
          'known',
          actualValue: 0,
        ),
        uncertaintyCase(
          'conflict-collapse',
          HardSafetyInvariantId.uncertaintyConflictNotCertain,
          'conflicting',
          'known',
          value: 5,
          conflictingValue: 7,
          actualValue: 5,
        ),
        uncertaintyCase(
          'estimate-collapse',
          HardSafetyInvariantId.uncertaintyEstimateNotKnown,
          'estimated',
          'known',
          value: 5,
          actualValue: 5,
        ),
      ]);

      expect(
          report.results.firstWhere((r) => r.caseId == 'missing-safe').passed,
          isTrue);
      expect(
        report.results
            .firstWhere((r) => r.caseId == 'missing-collapse')
            .reasonCode,
        'missing_collapsed',
      );
      expect(
        report.results
            .firstWhere((r) => r.caseId == 'conflict-collapse')
            .reasonCode,
        'conflict_collapsed',
      );
      expect(
        report.results
            .firstWhere((r) => r.caseId == 'estimate-collapse')
            .reasonCode,
        'estimate_collapsed',
      );
      expect(report.coverage.failedCases, 3);
    });

    test('permission production adapter respects exact revocation boundary',
        () {
      final suite = HardSafetySuite(observer: ProductionHardSafetyObserver());
      HardSafetyCase permissionCase(String id, DateTime requestAt) =>
          HardSafetyCase(
            id: id,
            invariantId: HardSafetyInvariantId.permissionRevocationBoundary,
            observedAt: requestAt,
            seed: 7,
            input: {
              'ownerId': 'owner',
              'recipientId': 'partner',
              'category': 'cycle',
              'createdAt': DateTime.utc(2026, 9, 16, 4).toIso8601String(),
              'revokedAt': at.toIso8601String(),
              'requestAt': requestAt.toIso8601String(),
            },
          );
      final report = suite.run(seed: 7, cases: [
        permissionCase('before', at.subtract(const Duration(seconds: 1))),
        permissionCase('boundary', at),
        permissionCase('after', at.add(const Duration(seconds: 1))),
      ]);
      expect(report.passed, isTrue);
      expect(
        report.results
            .firstWhere((r) => r.caseId == 'before')
            .evidence['allowed'],
        isTrue,
      );
      expect(
        report.results
            .firstWhere((r) => r.caseId == 'boundary')
            .evidence['allowed'],
        isFalse,
      );
    });

    test('detector fails S4 if access is observed at revocation boundary', () {
      final suite = HardSafetySuite(
        observer: _FixedObserver(const {
          'allowed': true,
          'atOrAfterRevocation': true,
        }),
      );
      final report = suite.run(
        seed: 7,
        cases: [
          HardSafetyCase(
            id: 'injected-boundary-breach',
            invariantId: HardSafetyInvariantId.permissionRevocationBoundary,
            observedAt: at,
            seed: 7,
          ),
        ],
      );
      expect(report.passed, isFalse);
      expect(report.results.single.severity, InvariantSeverity.s4);
      expect(report.results.single.reasonCode, 'revocation_breach');
    });
  });

  group('AI and doctor-review adapters', () {
    final at = DateTime.utc(2026, 9, 16, 6);

    test('blocked AI context is stopped before model invocation', () {
      final suite = HardSafetySuite(observer: ProductionHardSafetyObserver());
      final report = suite.run(
        seed: 10,
        cases: [
          HardSafetyCase(
            id: 'blocked-context',
            invariantId: HardSafetyInvariantId.aiContextFirewall,
            patientId: 'P-001',
            observedAt: at,
            seed: 10,
            input: const {
              'context': {
                'question': 'Summarize',
                'secretRecoveryKey': 'nope',
              },
              'allowedKeys': ['question'],
              'blockedKeys': ['secretRecoveryKey'],
              'mustReject': true,
            },
          ),
        ],
      );
      expect(report.passed, isTrue);
      expect(report.results.single.evidence['modelInvoked'], isFalse);
      expect(report.results.single.evidence['completedStage'], isFalse);
    });

    test('detector fails if blocked context crosses firewall', () {
      final suite = HardSafetySuite(
        observer: _FixedObserver(const {
          'mustReject': true,
          'validationFailed': false,
          'modelInvoked': true,
          'completedStage': true,
        }),
      );
      final report = suite.run(
        seed: 10,
        cases: [
          HardSafetyCase(
            id: 'firewall-breach',
            invariantId: HardSafetyInvariantId.aiContextFirewall,
            observedAt: at,
            seed: 10,
          ),
        ],
      );
      expect(report.results.single.passed, isFalse);
      expect(report.results.single.reasonCode, 'context_crossed_firewall');
    });

    test('missing and unknown evidence are rejected by production validator',
        () {
      final suite = HardSafetySuite(observer: ProductionHardSafetyObserver());
      HardSafetyCase evidenceCase(
        String id,
        List<String> evidenceIds,
        List<String> available,
      ) =>
          HardSafetyCase(
            id: id,
            invariantId: HardSafetyInvariantId.aiEvidenceRequired,
            patientId: 'P-001',
            observedAt: at,
            seed: 11,
            input: {
              'evidenceIds': evidenceIds,
              'availableEvidenceIds': available,
              'mustReject': true,
            },
          );
      final report = suite.run(seed: 11, cases: [
        evidenceCase('missing-evidence', const [], const []),
        evidenceCase('unknown-evidence', const ['evt-x'], const ['evt-known']),
      ]);
      expect(report.passed, isTrue);
      expect(
          report.results.every((r) => r.evidence['validationFailed'] == true),
          isTrue);
    });

    test('detector fails if unsupported evidence is accepted', () {
      final report = HardSafetySuite(
        observer: _FixedObserver(const {
          'mustReject': true,
          'validationFailed': false,
        }),
      ).run(
        seed: 11,
        cases: [
          HardSafetyCase(
            id: 'evidence-breach',
            invariantId: HardSafetyInvariantId.aiEvidenceRequired,
            observedAt: at,
            seed: 11,
          ),
        ],
      );
      expect(report.results.single.reasonCode, 'evidence_accepted');
      expect(report.results.single.severity, InvariantSeverity.s4);
    });

    test('all autonomous clinical actions are rejected', () {
      final suite = HardSafetySuite(observer: ProductionHardSafetyObserver());
      final actions = [
        'diagnose',
        'prescribe',
        'changeTreatment',
        'clinicalWrite'
      ];
      final report = suite.run(
        seed: 12,
        cases: [
          for (final action in actions)
            HardSafetyCase(
              id: 'action-$action',
              invariantId: HardSafetyInvariantId.aiAutonomousClinicalAction,
              patientId: 'P-001',
              observedAt: at,
              seed: 12,
              input: {'action': action, 'mustReject': true},
            ),
        ],
      );
      expect(report.passed, isTrue);
      expect(report.results.length, 4);
      expect(
          report.results.every((r) => r.evidence['validationFailed'] == true),
          isTrue);
    });

    test('detector fails if autonomous clinical action is accepted', () {
      final report = HardSafetySuite(
        observer: _FixedObserver(const {
          'mustReject': true,
          'validationFailed': false,
        }),
      ).run(
        seed: 12,
        cases: [
          HardSafetyCase(
            id: 'action-breach',
            invariantId: HardSafetyInvariantId.aiAutonomousClinicalAction,
            observedAt: at,
            seed: 12,
          ),
        ],
      );
      expect(report.results.single.reasonCode, 'autonomous_action_accepted');
    });

    test('doctor review gate blocks absent mismatched and rejected reviews',
        () {
      final suite = HardSafetySuite(observer: ProductionHardSafetyObserver());
      HardSafetyCase reviewCase(
        String id, {
        String? reviewProposalId,
        String? decision,
        required bool approvalExpected,
      }) =>
          HardSafetyCase(
            id: id,
            invariantId: HardSafetyInvariantId.clinicalDoctorReviewGate,
            patientId: 'P-001',
            observedAt: at,
            seed: 13,
            input: {
              'proposalId': 'proposal-1',
              if (reviewProposalId != null)
                'reviewProposalId': reviewProposalId,
              if (decision != null) 'reviewDecision': decision,
              'approvalExpected': approvalExpected,
            },
          );
      final report = suite.run(seed: 13, cases: [
        reviewCase('review-absent', approvalExpected: false),
        reviewCase(
          'review-mismatch',
          reviewProposalId: 'proposal-other',
          decision: 'approved',
          approvalExpected: false,
        ),
        reviewCase(
          'review-rejected',
          reviewProposalId: 'proposal-1',
          decision: 'rejected',
          approvalExpected: false,
        ),
        reviewCase(
          'review-approved',
          reviewProposalId: 'proposal-1',
          decision: 'approved',
          approvalExpected: true,
        ),
      ]);
      expect(report.passed, isTrue);
      expect(
          report.results
              .firstWhere((r) => r.caseId == 'review-approved')
              .evidence['commitAllowed'],
          isTrue);
    });

    test('detector fails if unapproved clinical write can commit', () {
      final report = HardSafetySuite(
        observer: _FixedObserver(const {
          'approvalExpected': false,
          'commitAllowed': true,
        }),
      ).run(
        seed: 13,
        cases: [
          HardSafetyCase(
            id: 'review-breach',
            invariantId: HardSafetyInvariantId.clinicalDoctorReviewGate,
            observedAt: at,
            seed: 13,
          ),
        ],
      );
      expect(report.results.single.reasonCode, 'review_gate_bypassed');
      expect(report.results.single.passed, isFalse);
    });
  });

  group('clinical truth preservation', () {
    final at = DateTime.utc(2026, 9, 16, 7);

    test(
        'production Playful Engine preserves truth for every clinical severity',
        () {
      final suite = HardSafetySuite(observer: ProductionHardSafetyObserver());
      final severities = ['informational', 'reviewRecommended', 'urgent'];
      final report = suite.run(
        seed: 14,
        cases: [
          for (final severity in severities)
            HardSafetyCase(
              id: 'truth-$severity',
              invariantId:
                  HardSafetyInvariantId.relationshipClinicalTruthPreserved,
              patientId: 'P-001',
              observedAt: at,
              seed: 14,
              input: {
                'ownerId': 'P-001',
                'recipientId': 'partner-1',
                'category': 'health',
                'truthText': 'Clinical truth $severity',
                'severity': severity,
                'preferencesEnabled': false,
                'companionText': 'Playful companion',
              },
            ),
        ],
      );
      expect(report.passed, isTrue);
      for (final result in report.results) {
        expect(result.evidence['truthPresent'], isTrue);
        expect(result.evidence['firstLayerKind'], 'clinicalTruth');
        expect(result.evidence['firstLayerTone'], 'plain');
      }
    });

    test('detector rejects omitted rewritten reordered and non-plain truth',
        () {
      HardSafetyReport evaluate(String id, Map<String, Object?> facts) =>
          HardSafetySuite(observer: _FixedObserver(facts)).run(
            seed: 15,
            cases: [
              HardSafetyCase(
                id: id,
                invariantId:
                    HardSafetyInvariantId.relationshipClinicalTruthPreserved,
                observedAt: at,
                seed: 15,
                input: const {'truthText': 'Must stay verbatim'},
              ),
            ],
          );

      final reports = [
        evaluate('truth-omitted', const {
          'truthPresent': false,
          'firstLayerKind': null,
          'firstLayerText': null,
          'firstLayerTone': null,
        }),
        evaluate('truth-rewritten', const {
          'truthPresent': true,
          'firstLayerKind': 'clinicalTruth',
          'firstLayerText': 'Changed text',
          'firstLayerTone': 'plain',
        }),
        evaluate('truth-reordered', const {
          'truthPresent': true,
          'firstLayerKind': 'companion',
          'firstLayerText': 'Must stay verbatim',
          'firstLayerTone': 'plain',
        }),
        evaluate('truth-tone', const {
          'truthPresent': true,
          'firstLayerKind': 'clinicalTruth',
          'firstLayerText': 'Must stay verbatim',
          'firstLayerTone': 'playful',
        }),
      ];
      expect(reports.every((report) => !report.passed), isTrue);
      expect(
        reports.every((report) =>
            report.results.single.reasonCode == 'clinical_truth_corrupted'),
        isTrue,
      );
      expect(
        reports.every(
            (report) => report.results.single.severity == InvariantSeverity.s4),
        isTrue,
      );
    });
  });

  group('fail-closed coverage and production smoke', () {
    final at = DateTime.utc(2026, 9, 16, 8);

    test('malformed adapter input fails closed and is counted', () {
      final report =
          HardSafetySuite(observer: ProductionHardSafetyObserver()).run(
        seed: 20,
        cases: [
          HardSafetyCase(
            id: 'malformed-evidence',
            invariantId: HardSafetyInvariantId.aiEvidenceRequired,
            observedAt: at,
            seed: 20,
            input: const {
              'evidenceIds': [],
              'mustReject': true,
            },
          ),
        ],
      );
      expect(report.passed, isFalse);
      expect(report.results.single.reasonCode, 'malformed_case');
      expect(report.results.single.severity, InvariantSeverity.s4);
      expect(report.coverage.malformedInputFailures, 1);
    });

    test('production smoke covers every hard invariant and is deterministic',
        () {
      final first = runProductionHardSafetySmoke(20260916);
      final second = runProductionHardSafetySmoke(20260916);
      expect(first.passed, isTrue);
      expect(second.toNormalizedJson(), first.toNormalizedJson());
      expect(
        first.coverage.perInvariant.keys.toSet(),
        HardSafetyInvariantId.values.map((item) => item.wireName).toSet(),
      );
      expect(first.coverage.failedCases, 0);
    });
  });
}

class _FixedObserver implements HardSafetyObserver {
  const _FixedObserver(this.facts);
  final Map<String, Object?> facts;
  @override
  HardSafetyObservation observe(HardSafetyCase safetyCase) =>
      HardSafetyObservation(facts: facts);
}
