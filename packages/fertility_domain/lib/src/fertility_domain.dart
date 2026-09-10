enum FertilityConfidence {
  insufficientInformation,
  low,
  medium,
  high,
}

enum PregnancySafetyDisposition {
  informational,
  reviewRecommended,
  urgentReviewRecommended,
}

enum PregnancyOutcomeType {
  liveBirth,
  pregnancyLoss,
  termination,
  ectopicPregnancy,
  unknown,
}

enum CervicalMucusQuality {
  dry,
  sticky,
  creamy,
  watery,
  eggWhite,
  unknown,
}

enum SexualActivityPrivacy {
  private,
  sharedWithCareTeam,
}

enum DataSharingConsent {
  notRecorded,
  allowed,
  withdrawn,
}

class DomainProvenance {
  const DomainProvenance({
    required this.sourceId,
    required this.recordedAt,
    this.note,
  });

  final String sourceId;
  final DateTime recordedAt;
  final String? note;
}

class SexualActivityEvent {
  const SexualActivityEvent({
    required this.id,
    required this.occurredAt,
    required this.provenance,
    this.contraceptionUsed,
    this.userMarkedConceptionRelevant = false,
    this.privacy = SexualActivityPrivacy.private,
    this.dataSharingConsent = DataSharingConsent.notRecorded,
  });

  final String id;
  final DateTime occurredAt;
  final DomainProvenance provenance;
  final bool? contraceptionUsed;
  final bool userMarkedConceptionRelevant;

  /// Controls visibility of this health-data record. It does not represent
  /// consent to the sexual activity itself.
  final SexualActivityPrivacy privacy;

  /// Explicit consent state for sharing this record only. Missing consent is
  /// never inferred as permission to share.
  final DataSharingConsent dataSharingConsent;

  bool get mayShareWithCareTeam =>
      privacy == SexualActivityPrivacy.sharedWithCareTeam &&
      dataSharingConsent == DataSharingConsent.allowed;
}

class ConceptionExposureEvent {
  const ConceptionExposureEvent({
    required this.id,
    required this.sexualActivityEventId,
    required this.occurredAt,
    required this.provenance,
  });

  final String id;
  final String sexualActivityEventId;
  final DateTime occurredAt;
  final DomainProvenance provenance;
}

class BasalBodyTemperatureObservation {
  const BasalBodyTemperatureObservation({
    required this.celsius,
    required this.observedAt,
    required this.provenance,
  });

  final double celsius;
  final DateTime observedAt;
  final DomainProvenance provenance;
}

class LhObservation {
  const LhObservation({
    required this.observedAt,
    required this.provenance,
    this.value,
    this.positive,
  });

  final DateTime observedAt;
  final DomainProvenance provenance;
  final double? value;
  final bool? positive;
}

class CervicalMucusObservation {
  const CervicalMucusObservation({
    required this.quality,
    required this.observedAt,
    required this.provenance,
  });

  final CervicalMucusQuality quality;
  final DateTime observedAt;
  final DomainProvenance provenance;
}

class FertilityEvidenceRef {
  const FertilityEvidenceRef({
    required this.kind,
    required this.sourceId,
  });

  final String kind;
  final String sourceId;
}

class FertilityAssessment {
  const FertilityAssessment({
    required this.confidence,
    required this.evidence,
    required this.missingInformation,
  });

  final FertilityConfidence confidence;
  final List<FertilityEvidenceRef> evidence;
  final Set<String> missingInformation;
}

/// Confidence describes observation completeness, not the probability of
/// ovulation, conception or pregnancy.
class FertilityConfidenceModel {
  const FertilityConfidenceModel();

  FertilityAssessment assess({
    required List<BasalBodyTemperatureObservation> bbt,
    required List<LhObservation> lh,
    required List<CervicalMucusObservation> mucus,
  }) {
    final evidence = <FertilityEvidenceRef>[];
    if (bbt.isNotEmpty) {
      evidence.add(
        FertilityEvidenceRef(
          kind: 'bbt',
          sourceId: bbt.last.provenance.sourceId,
        ),
      );
    }
    if (lh.isNotEmpty) {
      evidence.add(
        FertilityEvidenceRef(
          kind: 'lh',
          sourceId: lh.last.provenance.sourceId,
        ),
      );
    }
    if (mucus.isNotEmpty) {
      evidence.add(
        FertilityEvidenceRef(
          kind: 'mucus',
          sourceId: mucus.last.provenance.sourceId,
        ),
      );
    }

    final missing = <String>{
      if (bbt.isEmpty) 'bbt',
      if (lh.isEmpty) 'lh',
      if (mucus.isEmpty) 'mucus',
    };

    final confidence = switch (evidence.length) {
      3 => FertilityConfidence.high,
      2 => FertilityConfidence.medium,
      1 => FertilityConfidence.low,
      _ => FertilityConfidence.insufficientInformation,
    };

    return FertilityAssessment(
      confidence: confidence,
      evidence: List.unmodifiable(evidence),
      missingInformation: Set.unmodifiable(missing),
    );
  }
}

class PregnancyDating {
  const PregnancyDating({
    required this.estimatedStartDate,
    required this.basis,
    required this.provenance,
  });

  final DateTime estimatedStartDate;
  final String basis;
  final DomainProvenance provenance;
}

class PregnancyEpisode {
  const PregnancyEpisode({
    required this.id,
    required this.startedAt,
    required this.dating,
    this.endedAt,
    this.outcome,
  }) : assert(endedAt == null || !endedAt.isBefore(startedAt));

  final String id;
  final DateTime startedAt;
  final PregnancyDating dating;
  final DateTime? endedAt;
  final PregnancyOutcome? outcome;

  bool get isActive => endedAt == null;
}

class PregnancyVitalObservation {
  const PregnancyVitalObservation({
    required this.kind,
    required this.value,
    required this.unit,
    required this.observedAt,
    required this.provenance,
  });

  final String kind;
  final double value;
  final String unit;
  final DateTime observedAt;
  final DomainProvenance provenance;
}

class PregnancySymptomObservation {
  const PregnancySymptomObservation({
    required this.symptomKey,
    required this.observedAt,
    required this.provenance,
    this.severity,
  });

  final String symptomKey;
  final DateTime observedAt;
  final DomainProvenance provenance;
  final int? severity;
}

class PregnancySafetyRuleResult {
  const PregnancySafetyRuleResult({
    required this.ruleId,
    required this.disposition,
    required this.reason,
    required this.evidenceIds,
  });

  final String ruleId;
  final PregnancySafetyDisposition disposition;
  final String reason;
  final List<String> evidenceIds;
}

abstract interface class PregnancySafetyKernel {
  List<PregnancySafetyRuleResult> evaluate({
    required PregnancyEpisode episode,
    required List<PregnancyVitalObservation> vitals,
    required List<PregnancySymptomObservation> symptoms,
  });
}

class PregnancyOutcome {
  const PregnancyOutcome({
    required this.type,
    required this.occurredAt,
    required this.provenance,
  });

  final PregnancyOutcomeType type;
  final DateTime occurredAt;
  final DomainProvenance provenance;
}

class PostpartumEpisode {
  const PostpartumEpisode({
    required this.id,
    required this.pregnancyEpisodeId,
    required this.startedAt,
    this.endedAt,
  }) : assert(endedAt == null || !endedAt.isBefore(startedAt));

  final String id;
  final String pregnancyEpisodeId;
  final DateTime startedAt;
  final DateTime? endedAt;

  bool get isActive => endedAt == null;
}
