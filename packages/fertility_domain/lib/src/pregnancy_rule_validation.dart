import 'fertility_domain.dart';

enum PregnancyRuleValidationStatus { passed, failed }

enum PregnancyRuleValidationReason {
  passed,
  ruleSetVersionMismatch,
  dispositionMismatch,
  ruleOrderMismatch,
  evidenceMismatch,
  unsafeAutonomousAction,
}

class PregnancySafetyRuleSetVersion {
  const PregnancySafetyRuleSetVersion({
    required this.identifier,
    required this.version,
  });

  final String identifier;
  final String version;
}

class PregnancySafetyValidationFixture {
  const PregnancySafetyValidationFixture({
    required this.id,
    required this.ruleSet,
    required this.expectedRuleSet,
    required this.episode,
    required this.vitals,
    required this.symptoms,
    required this.expectedRuleIds,
    required this.expectedDispositions,
    this.expectedEvidenceIds = const {},
  });

  final String id;
  final PregnancySafetyRuleSetVersion ruleSet;
  final PregnancySafetyRuleSetVersion expectedRuleSet;
  final PregnancyEpisode episode;
  final List<PregnancyVitalObservation> vitals;
  final List<PregnancySymptomObservation> symptoms;
  final List<String> expectedRuleIds;
  final List<PregnancySafetyDisposition> expectedDispositions;
  final Set<String> expectedEvidenceIds;
}

class PregnancyRuleValidationResult {
  const PregnancyRuleValidationResult({
    required this.fixtureId,
    required this.status,
    required this.reason,
  });

  final String fixtureId;
  final PregnancyRuleValidationStatus status;
  final PregnancyRuleValidationReason reason;

  Map<String, String> toJson() => {
        'fixtureId': fixtureId,
        'status': status.name,
        'reason': reason.name,
      };
}

class PregnancySafetyRuleValidator {
  const PregnancySafetyRuleValidator();

  PregnancyRuleValidationResult validate({
    required PregnancySafetyValidationFixture fixture,
    required PregnancySafetyKernel kernel,
  }) {
    if (fixture.ruleSet.identifier != fixture.expectedRuleSet.identifier ||
        fixture.ruleSet.version != fixture.expectedRuleSet.version) {
      return _failed(
        fixture.id,
        PregnancyRuleValidationReason.ruleSetVersionMismatch,
      );
    }

    final results = kernel.evaluate(
      episode: fixture.episode,
      vitals: fixture.vitals,
      symptoms: fixture.symptoms,
    );

    final ruleIds = results.map((result) => result.ruleId).toList();
    if (!_sameList(ruleIds, fixture.expectedRuleIds)) {
      return _failed(fixture.id, PregnancyRuleValidationReason.ruleOrderMismatch);
    }

    final dispositions = results.map((result) => result.disposition).toList();
    if (!_sameList(dispositions, fixture.expectedDispositions)) {
      return _failed(
        fixture.id,
        PregnancyRuleValidationReason.dispositionMismatch,
      );
    }

    final evidenceIds = results.expand((result) => result.evidenceIds).toSet();
    if (!_sameSet(evidenceIds, fixture.expectedEvidenceIds)) {
      return _failed(fixture.id, PregnancyRuleValidationReason.evidenceMismatch);
    }

    // The production kernel result type intentionally has no diagnosis,
    // prescription or treatment-change action channel. Reject common action
    // directives if they are ever smuggled through free-text reasons.
    final unsafe = results.any((result) {
      final reason = result.reason.toLowerCase();
      return reason.contains('diagnose ') ||
          reason.contains('prescribe ') ||
          reason.contains('start medication') ||
          reason.contains('stop medication') ||
          reason.contains('change dose');
    });
    if (unsafe) {
      return _failed(
        fixture.id,
        PregnancyRuleValidationReason.unsafeAutonomousAction,
      );
    }

    return PregnancyRuleValidationResult(
      fixtureId: fixture.id,
      status: PregnancyRuleValidationStatus.passed,
      reason: PregnancyRuleValidationReason.passed,
    );
  }

  static PregnancyRuleValidationResult _failed(
    String id,
    PregnancyRuleValidationReason reason,
  ) =>
      PregnancyRuleValidationResult(
        fixtureId: id,
        status: PregnancyRuleValidationStatus.failed,
        reason: reason,
      );

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
