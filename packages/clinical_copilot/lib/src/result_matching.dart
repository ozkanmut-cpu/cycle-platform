import 'package:cycle_core_domain/cycle_core_domain.dart';

import 'clinical_copilot.dart';

enum ResultMatchStatus { matched, missing, outOfWindow }

class MatchedResult {
  const MatchedResult({
    required this.requirement,
    required this.status,
    required this.eventIds,
  });

  final String requirement;
  final ResultMatchStatus status;
  final List<String> eventIds;
}

class TreatmentTrialResultMatch {
  const TreatmentTrialResultMatch({
    required this.trialId,
    required this.results,
  });

  final String trialId;
  final List<MatchedResult> results;

  bool get hasMissing =>
      results.any((result) => result.status == ResultMatchStatus.missing);
}

class ClinicalQuestionResultMatch {
  const ClinicalQuestionResultMatch({
    required this.protocolId,
    required this.results,
  });

  final String protocolId;
  final List<MatchedResult> results;

  bool get hasMissing =>
      results.any((result) => result.status == ResultMatchStatus.missing);
}

class DoctorResultMatcher {
  const DoctorResultMatcher();

  TreatmentTrialResultMatch matchTreatmentTrial({
    required TreatmentTrialHook trial,
    required Iterable<HealthEvent> events,
  }) {
    if (trial.endAt.isBefore(trial.startAt)) {
      throw ArgumentError('Treatment trial endAt must not precede startAt.');
    }

    final patientEvents = _sortedPatientEvents(events, trial.patientId);
    final results = <MatchedResult>[];

    for (final eventType in _stableUnique(trial.outcomeEventTypes)) {
      final sameType = patientEvents
          .where((event) => event.eventType == eventType)
          .toList(growable: false);
      final inWindow = sameType
          .where(
            (event) =>
                !event.temporal.observedAt.isBefore(trial.startAt) &&
                !event.temporal.observedAt.isAfter(trial.endAt),
          )
          .toList(growable: false);

      if (inWindow.isNotEmpty) {
        results.add(
          MatchedResult(
            requirement: eventType,
            status: ResultMatchStatus.matched,
            eventIds: _eventIds(inWindow),
          ),
        );
      } else if (sameType.isNotEmpty) {
        results.add(
          MatchedResult(
            requirement: eventType,
            status: ResultMatchStatus.outOfWindow,
            eventIds: _eventIds(sameType),
          ),
        );
      } else {
        results.add(
          MatchedResult(
            requirement: eventType,
            status: ResultMatchStatus.missing,
            eventIds: const <String>[],
          ),
        );
      }
    }

    return TreatmentTrialResultMatch(
      trialId: trial.id,
      results: List<MatchedResult>.unmodifiable(results),
    );
  }

  ClinicalQuestionResultMatch matchClinicalQuestion({
    required ClinicalQuestionProtocolHook protocol,
    required Iterable<HealthEvent> events,
  }) {
    final patientEvents = _sortedPatientEvents(events, protocol.patientId);
    final results = <MatchedResult>[];

    for (final evidenceType in _stableUnique(protocol.requiredEvidenceTypes)) {
      final matching = patientEvents
          .where((event) => event.eventType == evidenceType)
          .toList(growable: false);
      results.add(
        MatchedResult(
          requirement: evidenceType,
          status: matching.isEmpty
              ? ResultMatchStatus.missing
              : ResultMatchStatus.matched,
          eventIds: _eventIds(matching),
        ),
      );
    }

    return ClinicalQuestionResultMatch(
      protocolId: protocol.id,
      results: List<MatchedResult>.unmodifiable(results),
    );
  }

  List<HealthEvent> _sortedPatientEvents(
    Iterable<HealthEvent> events,
    String patientId,
  ) {
    final output = events
        .where((event) => event.subjectId == patientId)
        .toList(growable: false);
    output.sort((left, right) {
      final byTime =
          left.temporal.observedAt.compareTo(right.temporal.observedAt);
      return byTime != 0 ? byTime : left.id.compareTo(right.id);
    });
    return output;
  }

  List<String> _eventIds(Iterable<HealthEvent> events) =>
      List<String>.unmodifiable(events.map((event) => event.id));

  List<String> _stableUnique(Iterable<String> values) {
    final output = values.toSet().toList()..sort();
    return output;
  }
}
