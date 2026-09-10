import 'package:cycle_clinical_copilot/cycle_clinical_copilot.dart';
import 'package:test/test.dart';

void main() {
  group('AI context firewall', () {
    test('passes only explicitly allowlisted context', () {
      const firewall = AiContextFirewall();
      final result = firewall.filter(
        context: const {
          'snapshot': 'stable',
          'patientName': 'blocked-by-allowlist',
        },
        policy: AiContextPolicy(allowedKeys: const {'snapshot'}),
      );

      expect(result.validation.disposition, AiValidationDisposition.fail);
      expect(result.allowedContext, {'snapshot': 'stable'});
      expect(result.blockedKeys, ['patientName']);
      expect(
        result.validation.reasons,
        contains(AiValidationReason.disallowedContextField),
      );
    });

    test('explicit blocked fields are never passed through', () {
      const firewall = AiContextFirewall();
      final result = firewall.filter(
        context: const {'summary': 'ok', 'secret': 'no'},
        policy: AiContextPolicy(
          allowedKeys: const {'summary', 'secret'},
          blockedKeys: const {'secret'},
        ),
      );

      expect(result.allowedContext, {'summary': 'ok'});
      expect(
        result.validation.reasons,
        contains(AiValidationReason.blockedContextField),
      );
    });
  });

  group('AI validators', () {
    test('evidence validator rejects missing and unknown evidence', () {
      const validator = AiEvidenceValidator();
      final missing = validator.validate(
        output: AiCandidateOutput(
          text: 'claim',
          claims: [AiClaim(text: 'unsupported')],
        ),
        availableEvidenceIds: const {'evt-1'},
      );
      final unknown = validator.validate(
        output: AiCandidateOutput(
          text: 'claim',
          claims: [
            AiClaim(text: 'unknown', evidenceIds: const ['evt-2'])
          ],
        ),
        availableEvidenceIds: const {'evt-1'},
      );

      expect(missing.disposition, AiValidationDisposition.fail);
      expect(missing.reasons, contains(AiValidationReason.missingEvidence));
      expect(unknown.disposition, AiValidationDisposition.fail);
      expect(unknown.reasons, contains(AiValidationReason.unknownEvidence));
    });

    test('safety validator blocks autonomous clinical actions', () {
      const validator = AiSafetyValidator();
      final result = validator.validate(
        AiCandidateOutput(
          text: 'unsafe',
          proposedActions: const [
            AiClinicalAction.diagnose,
            AiClinicalAction.prescribe,
            AiClinicalAction.changeTreatment,
            AiClinicalAction.clinicalWrite,
          ],
        ),
      );

      expect(result.disposition, AiValidationDisposition.fail);
      expect(result.reasons, contains(AiValidationReason.autonomousDiagnosis));
      expect(result.reasons, contains(AiValidationReason.prescribing));
      expect(result.reasons, contains(AiValidationReason.treatmentChange));
      expect(result.reasons, contains(AiValidationReason.clinicalWrite));
    });

    test('safe output can explicitly require doctor review', () {
      const validator = AiSafetyValidator();
      final result = validator.validate(
        AiCandidateOutput(text: 'review', requiresDoctorReview: true),
      );

      expect(result.disposition, AiValidationDisposition.reviewRequired);
      expect(
        result.reasons,
        [AiValidationReason.doctorReviewRequired],
      );
    });
  });

  group('AI orchestrator', () {
    final request = AiOrchestrationRequest(
      id: 'req-1',
      patientId: 'patient-1',
      purpose: 'clinical-summary',
      context: const {'snapshot': 'stable'},
      availableEvidenceIds: const {'evt-1'},
      requestedAt: DateTime.utc(2026, 9, 10, 16),
    );

    test('runs deterministic audited validation flow', () {
      const orchestrator = AiOrchestrator();
      final result = orchestrator.run(
        request: request,
        contextPolicy: AiContextPolicy(allowedKeys: const {'snapshot'}),
        invokeModel: (context) => AiCandidateOutput(
          text: 'supported summary',
          claims: [
            AiClaim(text: 'supported', evidenceIds: const ['evt-1']),
          ],
        ),
      );

      expect(result.disposition, AiValidationDisposition.pass);
      expect(
        result.audit.map((entry) => entry.stage),
        [
          AiOrchestrationStage.contextFirewall,
          AiOrchestrationStage.modelInvocation,
          AiOrchestrationStage.evidenceValidation,
          AiOrchestrationStage.safetyValidation,
          AiOrchestrationStage.completed,
        ],
      );
      expect(
        result.audit.every(
          (entry) => entry.recordedAt == DateTime.utc(2026, 9, 10, 16),
        ),
        isTrue,
      );
    });

    test('does not invoke model when context firewall fails', () {
      const orchestrator = AiOrchestrator();
      var invoked = false;
      final blockedRequest = AiOrchestrationRequest(
        id: 'req-blocked',
        patientId: 'patient-1',
        purpose: 'clinical-summary',
        context: const {'secret': 'blocked'},
        availableEvidenceIds: const {},
        requestedAt: DateTime.utc(2026, 9, 10, 16),
      );

      final result = orchestrator.run(
        request: blockedRequest,
        contextPolicy: AiContextPolicy(allowedKeys: const {'snapshot'}),
        invokeModel: (context) {
          invoked = true;
          return AiCandidateOutput(text: 'should-not-run');
        },
      );

      expect(invoked, isFalse);
      expect(result.disposition, AiValidationDisposition.fail);
      expect(result.output, isNull);
      expect(result.audit, hasLength(1));
    });

    test('has no autonomous record commit output', () {
      final resultFields = AiOrchestrationResult(
        requestId: 'r',
        disposition: AiValidationDisposition.pass,
        audit: const [],
      );

      expect(resultFields.output, isNull);
      expect(resultFields.audit, isEmpty);
    });
  });
}
