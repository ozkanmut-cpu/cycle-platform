import 'condition_pack.dart';

enum RuleValidationStatus { passed, failed }

enum RuleValidationReason {
  passed,
  guidelineIdentifierMismatch,
  guidelineVersionMismatch,
  confidenceMismatch,
  candidateOrderMismatch,
  missingInformationMismatch,
}

class RoutingValidationFixture {
  const RoutingValidationFixture({
    required this.id,
    required this.guidelineIdentifier,
    required this.guidelineVersion,
    required this.report,
    required this.packs,
    required this.expectedConfidence,
    required this.expectedCandidateIds,
    this.expectedMissingInformation = const {},
  });

  final String id;
  final String guidelineIdentifier;
  final String guidelineVersion;
  final SymptomReport report;
  final List<ConditionPack> packs;
  final RoutingConfidence expectedConfidence;
  final List<String> expectedCandidateIds;
  final Set<String> expectedMissingInformation;
}

class RuleValidationResult {
  const RuleValidationResult({
    required this.fixtureId,
    required this.status,
    required this.reason,
  });

  final String fixtureId;
  final RuleValidationStatus status;
  final RuleValidationReason reason;

  Map<String, String> toJson() => {
        'fixtureId': fixtureId,
        'status': status.name,
        'reason': reason.name,
      };
}

class SymptomRoutingRuleValidator {
  const SymptomRoutingRuleValidator({this.router = const SymptomFirstRouter()});

  final SymptomFirstRouter router;

  RuleValidationResult validate(RoutingValidationFixture fixture) {
    for (final pack in fixture.packs) {
      if (pack.guideline.identifier != fixture.guidelineIdentifier) {
        return _failed(
          fixture.id,
          RuleValidationReason.guidelineIdentifierMismatch,
        );
      }
      if (pack.guideline.version != fixture.guidelineVersion) {
        return _failed(
          fixture.id,
          RuleValidationReason.guidelineVersionMismatch,
        );
      }
    }

    final result = router.route(report: fixture.report, packs: fixture.packs);
    if (result.confidence != fixture.expectedConfidence) {
      return _failed(fixture.id, RuleValidationReason.confidenceMismatch);
    }

    final actualIds = result.matches.map((match) => match.pack.id).toList();
    if (!_sameList(actualIds, fixture.expectedCandidateIds)) {
      return _failed(fixture.id, RuleValidationReason.candidateOrderMismatch);
    }

    if (!_sameSet(result.missingInformation, fixture.expectedMissingInformation)) {
      return _failed(
        fixture.id,
        RuleValidationReason.missingInformationMismatch,
      );
    }

    return RuleValidationResult(
      fixtureId: fixture.id,
      status: RuleValidationStatus.passed,
      reason: RuleValidationReason.passed,
    );
  }

  static RuleValidationResult _failed(
    String id,
    RuleValidationReason reason,
  ) =>
      RuleValidationResult(
        fixtureId: id,
        status: RuleValidationStatus.failed,
        reason: reason,
      );

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
