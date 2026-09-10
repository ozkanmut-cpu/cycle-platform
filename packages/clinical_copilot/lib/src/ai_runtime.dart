enum AiValidationDisposition { pass, fail, reviewRequired }

enum AiValidationReason {
  none,
  blockedContextField,
  disallowedContextField,
  missingEvidence,
  unknownEvidence,
  autonomousDiagnosis,
  prescribing,
  treatmentChange,
  clinicalWrite,
  doctorReviewRequired,
}

enum AiClinicalAction {
  none,
  diagnose,
  prescribe,
  changeTreatment,
  clinicalWrite,
}

enum AiOrchestrationStage {
  contextFirewall,
  modelInvocation,
  evidenceValidation,
  safetyValidation,
  completed,
}

class AiValidationResult {
  AiValidationResult({
    required this.disposition,
    required Iterable<AiValidationReason> reasons,
  }) : reasons = List<AiValidationReason>.unmodifiable(reasons);

  final AiValidationDisposition disposition;
  final List<AiValidationReason> reasons;

  bool get passed => disposition == AiValidationDisposition.pass;
}

class AiContextPolicy {
  AiContextPolicy({
    required Iterable<String> allowedKeys,
    Iterable<String> blockedKeys = const <String>[],
  })  : allowedKeys = Set<String>.unmodifiable(allowedKeys),
        blockedKeys = Set<String>.unmodifiable(blockedKeys);

  final Set<String> allowedKeys;
  final Set<String> blockedKeys;
}

class AiContextFirewallResult {
  AiContextFirewallResult({
    required Map<String, Object?> allowedContext,
    required Iterable<String> blockedKeys,
    required this.validation,
  })  : allowedContext = Map<String, Object?>.unmodifiable(allowedContext),
        blockedKeys = List<String>.unmodifiable(blockedKeys);

  final Map<String, Object?> allowedContext;
  final List<String> blockedKeys;
  final AiValidationResult validation;
}

class AiContextFirewall {
  const AiContextFirewall();

  AiContextFirewallResult filter({
    required Map<String, Object?> context,
    required AiContextPolicy policy,
  }) {
    final allowed = <String, Object?>{};
    final blocked = <String>[];
    final reasons = <AiValidationReason>{};

    final keys = context.keys.toList()..sort();
    for (final key in keys) {
      if (policy.blockedKeys.contains(key)) {
        blocked.add(key);
        reasons.add(AiValidationReason.blockedContextField);
        continue;
      }
      if (!policy.allowedKeys.contains(key)) {
        blocked.add(key);
        reasons.add(AiValidationReason.disallowedContextField);
        continue;
      }
      allowed[key] = context[key];
    }

    return AiContextFirewallResult(
      allowedContext: allowed,
      blockedKeys: blocked,
      validation: AiValidationResult(
        disposition: reasons.isEmpty
            ? AiValidationDisposition.pass
            : AiValidationDisposition.fail,
        reasons: reasons.isEmpty ? const [AiValidationReason.none] : reasons,
      ),
    );
  }
}

class AiClaim {
  AiClaim({
    required this.text,
    Iterable<String> evidenceIds = const <String>[],
    this.evidenceRequired = true,
  }) : evidenceIds = List<String>.unmodifiable(evidenceIds);

  final String text;
  final List<String> evidenceIds;
  final bool evidenceRequired;
}

class AiCandidateOutput {
  AiCandidateOutput({
    required this.text,
    Iterable<AiClaim> claims = const <AiClaim>[],
    Iterable<AiClinicalAction> proposedActions = const <AiClinicalAction>[],
    this.requiresDoctorReview = false,
  })  : claims = List<AiClaim>.unmodifiable(claims),
        proposedActions = List<AiClinicalAction>.unmodifiable(proposedActions);

  final String text;
  final List<AiClaim> claims;
  final List<AiClinicalAction> proposedActions;
  final bool requiresDoctorReview;
}

class AiEvidenceValidator {
  const AiEvidenceValidator();

  AiValidationResult validate({
    required AiCandidateOutput output,
    required Set<String> availableEvidenceIds,
  }) {
    final reasons = <AiValidationReason>{};
    for (final claim in output.claims) {
      if (claim.evidenceRequired && claim.evidenceIds.isEmpty) {
        reasons.add(AiValidationReason.missingEvidence);
      }
      if (claim.evidenceIds.any((id) => !availableEvidenceIds.contains(id))) {
        reasons.add(AiValidationReason.unknownEvidence);
      }
    }
    return AiValidationResult(
      disposition: reasons.isEmpty
          ? AiValidationDisposition.pass
          : AiValidationDisposition.fail,
      reasons: reasons.isEmpty ? const [AiValidationReason.none] : reasons,
    );
  }
}

class AiSafetyValidator {
  const AiSafetyValidator();

  AiValidationResult validate(AiCandidateOutput output) {
    final reasons = <AiValidationReason>{};
    for (final action in output.proposedActions) {
      switch (action) {
        case AiClinicalAction.none:
          break;
        case AiClinicalAction.diagnose:
          reasons.add(AiValidationReason.autonomousDiagnosis);
        case AiClinicalAction.prescribe:
          reasons.add(AiValidationReason.prescribing);
        case AiClinicalAction.changeTreatment:
          reasons.add(AiValidationReason.treatmentChange);
        case AiClinicalAction.clinicalWrite:
          reasons.add(AiValidationReason.clinicalWrite);
      }
    }
    if (reasons.isNotEmpty) {
      return AiValidationResult(
        disposition: AiValidationDisposition.fail,
        reasons: reasons,
      );
    }
    if (output.requiresDoctorReview) {
      return AiValidationResult(
        disposition: AiValidationDisposition.reviewRequired,
        reasons: const [AiValidationReason.doctorReviewRequired],
      );
    }
    return AiValidationResult(
      disposition: AiValidationDisposition.pass,
      reasons: const [AiValidationReason.none],
    );
  }
}

class AiOrchestrationRequest {
  AiOrchestrationRequest({
    required this.id,
    required this.patientId,
    required this.purpose,
    required Map<String, Object?> context,
    required Iterable<String> availableEvidenceIds,
    required this.requestedAt,
  })  : context = Map<String, Object?>.unmodifiable(context),
        availableEvidenceIds = Set<String>.unmodifiable(availableEvidenceIds);

  final String id;
  final String patientId;
  final String purpose;
  final Map<String, Object?> context;
  final Set<String> availableEvidenceIds;
  final DateTime requestedAt;
}

class AiOrchestrationAuditEntry {
  const AiOrchestrationAuditEntry({
    required this.stage,
    required this.disposition,
    required this.detail,
    required this.recordedAt,
  });

  final AiOrchestrationStage stage;
  final AiValidationDisposition disposition;
  final String detail;
  final DateTime recordedAt;
}

class AiOrchestrationResult {
  AiOrchestrationResult({
    required this.requestId,
    required this.disposition,
    required Iterable<AiOrchestrationAuditEntry> audit,
    this.output,
  }) : audit = List<AiOrchestrationAuditEntry>.unmodifiable(audit);

  final String requestId;
  final AiValidationDisposition disposition;
  final AiCandidateOutput? output;
  final List<AiOrchestrationAuditEntry> audit;
}

typedef AiModelInvoker = AiCandidateOutput Function(
  Map<String, Object?> allowedContext,
);

class AiOrchestrator {
  const AiOrchestrator({
    this.firewall = const AiContextFirewall(),
    this.evidenceValidator = const AiEvidenceValidator(),
    this.safetyValidator = const AiSafetyValidator(),
  });

  final AiContextFirewall firewall;
  final AiEvidenceValidator evidenceValidator;
  final AiSafetyValidator safetyValidator;

  AiOrchestrationResult run({
    required AiOrchestrationRequest request,
    required AiContextPolicy contextPolicy,
    required AiModelInvoker invokeModel,
  }) {
    final audit = <AiOrchestrationAuditEntry>[];
    final timestamp = request.requestedAt.toUtc();
    final filtered = firewall.filter(context: request.context, policy: contextPolicy);
    audit.add(
      AiOrchestrationAuditEntry(
        stage: AiOrchestrationStage.contextFirewall,
        disposition: filtered.validation.disposition,
        detail: filtered.blockedKeys.join(','),
        recordedAt: timestamp,
      ),
    );
    if (!filtered.validation.passed) {
      return AiOrchestrationResult(
        requestId: request.id,
        disposition: AiValidationDisposition.fail,
        audit: audit,
      );
    }

    final output = invokeModel(filtered.allowedContext);
    audit.add(
      AiOrchestrationAuditEntry(
        stage: AiOrchestrationStage.modelInvocation,
        disposition: AiValidationDisposition.pass,
        detail: request.purpose,
        recordedAt: timestamp,
      ),
    );

    final evidence = evidenceValidator.validate(
      output: output,
      availableEvidenceIds: request.availableEvidenceIds,
    );
    audit.add(
      AiOrchestrationAuditEntry(
        stage: AiOrchestrationStage.evidenceValidation,
        disposition: evidence.disposition,
        detail: evidence.reasons.map((reason) => reason.name).join(','),
        recordedAt: timestamp,
      ),
    );
    if (evidence.disposition == AiValidationDisposition.fail) {
      return AiOrchestrationResult(
        requestId: request.id,
        disposition: AiValidationDisposition.fail,
        audit: audit,
        output: output,
      );
    }

    final safety = safetyValidator.validate(output);
    audit.add(
      AiOrchestrationAuditEntry(
        stage: AiOrchestrationStage.safetyValidation,
        disposition: safety.disposition,
        detail: safety.reasons.map((reason) => reason.name).join(','),
        recordedAt: timestamp,
      ),
    );
    if (safety.disposition == AiValidationDisposition.fail) {
      return AiOrchestrationResult(
        requestId: request.id,
        disposition: AiValidationDisposition.fail,
        audit: audit,
        output: output,
      );
    }

    audit.add(
      AiOrchestrationAuditEntry(
        stage: AiOrchestrationStage.completed,
        disposition: safety.disposition,
        detail: 'validated-output',
        recordedAt: timestamp,
      ),
    );
    return AiOrchestrationResult(
      requestId: request.id,
      disposition: safety.disposition,
      audit: audit,
      output: output,
    );
  }
}
