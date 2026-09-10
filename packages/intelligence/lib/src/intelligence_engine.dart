import 'dart:math' as math;

import 'package:cycle_core_domain/cycle_core_domain.dart';

enum UncertaintyState {
  known,
  unknown,
  estimated,
  conflicting,
  stale,
  incomplete,
  lowConfidence,
}

class IntelligenceDatum {
  const IntelligenceDatum({
    required this.event,
    required this.uncertainty,
  });

  final HealthEvent event;
  final Set<UncertaintyState> uncertainty;

  bool get isKnown => uncertainty.length == 1 && uncertainty.contains(UncertaintyState.known);
}

class UncertaintyEngine {
  const UncertaintyEngine({this.staleAfter = const Duration(days: 30)});

  final Duration staleAfter;

  IntelligenceDatum evaluate(
    HealthEvent event, {
    required DateTime now,
    bool incompleteHistory = false,
    bool conflicting = false,
  }) {
    final states = <UncertaintyState>{};

    if (event.dataState == DataState.unknown ||
        event.dataState == DataState.notRecorded ||
        (event.value == null && event.dataState == null)) {
      states.add(UncertaintyState.unknown);
    }
    if (event.verificationStatus == VerificationStatus.estimated) {
      states.add(UncertaintyState.estimated);
    }
    if (conflicting) states.add(UncertaintyState.conflicting);
    if (now.toUtc().difference(event.temporal.observedAt.toUtc()) > staleAfter) {
      states.add(UncertaintyState.stale);
    }
    if (incompleteHistory) states.add(UncertaintyState.incomplete);
    if (event.confidence == ConfidenceClass.low ||
        event.confidence == ConfidenceClass.unknown) {
      states.add(UncertaintyState.lowConfidence);
    }
    if (states.isEmpty) states.add(UncertaintyState.known);
    return IntelligenceDatum(event: event, uncertainty: Set.unmodifiable(states));
  }
}

class Baseline {
  const Baseline({
    required this.eventType,
    required this.count,
    required this.mean,
    required this.median,
    required this.minimum,
    required this.maximum,
    required this.standardDeviation,
    required this.windowStart,
    required this.windowEnd,
  });

  final String eventType;
  final int count;
  final double mean;
  final double median;
  final double minimum;
  final double maximum;
  final double standardDeviation;
  final DateTime windowStart;
  final DateTime windowEnd;
}

class PersonalBaselineEngine {
  const PersonalBaselineEngine();

  Baseline? calculate(
    Iterable<HealthEvent> events, {
    required String eventType,
    required DateTime from,
    required DateTime to,
  }) {
    final selected = events
        .where((event) =>
            event.eventType == eventType &&
            event.value != null &&
            !event.temporal.observedAt.isBefore(from) &&
            !event.temporal.observedAt.isAfter(to))
        .map((event) => event.value!.toDouble())
        .toList()
      ..sort();
    if (selected.isEmpty) return null;

    final mean = selected.reduce((a, b) => a + b) / selected.length;
    final median = selected.length.isOdd
        ? selected[selected.length ~/ 2]
        : (selected[selected.length ~/ 2 - 1] + selected[selected.length ~/ 2]) / 2;
    final variance = selected
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        selected.length;

    return Baseline(
      eventType: eventType,
      count: selected.length,
      mean: mean,
      median: median,
      minimum: selected.first,
      maximum: selected.last,
      standardDeviation: math.sqrt(variance),
      windowStart: from,
      windowEnd: to,
    );
  }
}

enum ChangeDirection { increased, decreased, stable, insufficientData }

class TemporalComparison {
  const TemporalComparison({
    required this.eventType,
    required this.previousMean,
    required this.currentMean,
    required this.absoluteChange,
    required this.percentChange,
    required this.direction,
  });

  final String eventType;
  final double? previousMean;
  final double? currentMean;
  final double? absoluteChange;
  final double? percentChange;
  final ChangeDirection direction;
}

class TemporalEngine {
  const TemporalEngine();

  TemporalComparison compare({
    required String eventType,
    required Baseline? previous,
    required Baseline? current,
    double stableTolerancePercent = 1,
  }) {
    if (previous == null || current == null) {
      return TemporalComparison(
        eventType: eventType,
        previousMean: previous?.mean,
        currentMean: current?.mean,
        absoluteChange: null,
        percentChange: null,
        direction: ChangeDirection.insufficientData,
      );
    }
    final absolute = current.mean - previous.mean;
    final percent = previous.mean == 0 ? null : (absolute / previous.mean) * 100;
    final direction = percent == null || percent.abs() <= stableTolerancePercent
        ? ChangeDirection.stable
        : (percent > 0 ? ChangeDirection.increased : ChangeDirection.decreased);
    return TemporalComparison(
      eventType: eventType,
      previousMean: previous.mean,
      currentMean: current.mean,
      absoluteChange: absolute,
      percentChange: percent,
      direction: direction,
    );
  }
}

class Contradiction {
  const Contradiction({
    required this.eventType,
    required this.eventIds,
    required this.reason,
  });

  final String eventType;
  final List<String> eventIds;
  final String reason;
}

class ContradictionDetector {
  const ContradictionDetector();

  List<Contradiction> detect(
    Iterable<HealthEvent> events, {
    Duration sameMomentTolerance = const Duration(minutes: 5),
    double numericTolerance = 0,
  }) {
    final list = events.toList();
    final contradictions = <Contradiction>[];
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = list[i];
        final b = list[j];
        if (a.subjectId != b.subjectId || a.eventType != b.eventType) continue;
        if (a.temporal.observedAt.difference(b.temporal.observedAt).abs() >
            sameMomentTolerance) {
          continue;
        }
        final numericConflict = a.value != null &&
            b.value != null &&
            (a.value!.toDouble() - b.value!.toDouble()).abs() > numericTolerance;
        final stateConflict = a.dataState != null &&
            b.dataState != null &&
            a.dataState != b.dataState &&
            {a.dataState, b.dataState}.contains(DataState.yes) &&
            {a.dataState, b.dataState}.contains(DataState.no);
        if (numericConflict || stateConflict) {
          contradictions.add(Contradiction(
            eventType: a.eventType,
            eventIds: [a.id, b.id],
            reason: numericConflict ? 'numeric_disagreement' : 'state_disagreement',
          ));
        }
      }
    }
    return contradictions;
  }
}

class InformationValue {
  const InformationValue({
    required this.score,
    required this.shouldAsk,
    required this.reasons,
  });

  final double score;
  final bool shouldAsk;
  final List<String> reasons;
}

class InformationValueEngine {
  const InformationValueEngine({this.askThreshold = 0.6});

  final double askThreshold;

  InformationValue score({
    required double decisionRelevance,
    required double uncertainty,
    required double actionability,
    required double userBurden,
  }) {
    double clamp(double value) => value.clamp(0, 1).toDouble();
    final relevance = clamp(decisionRelevance);
    final unknown = clamp(uncertainty);
    final actionable = clamp(actionability);
    final burden = clamp(userBurden);
    final score = clamp((0.4 * relevance) + (0.35 * unknown) + (0.25 * actionable) - (0.35 * burden));
    final reasons = <String>[];
    if (relevance >= 0.7) reasons.add('decision_relevant');
    if (unknown >= 0.7) reasons.add('reduces_uncertainty');
    if (actionable >= 0.7) reasons.add('actionable');
    if (burden >= 0.7) reasons.add('high_user_burden');
    return InformationValue(
      score: score,
      shouldAsk: score >= askThreshold,
      reasons: List.unmodifiable(reasons),
    );
  }
}

class ZeroLogDecision {
  const ZeroLogDecision({
    required this.promptUser,
    required this.reason,
    required this.informationValue,
  });

  final bool promptUser;
  final String reason;
  final InformationValue informationValue;
}

class ZeroLogDayEngine {
  const ZeroLogDayEngine({this.informationValueEngine = const InformationValueEngine()});

  final InformationValueEngine informationValueEngine;

  ZeroLogDecision decide({
    required bool hasUserLoggedToday,
    required bool hasPassiveDataToday,
    required double decisionRelevance,
    required double uncertainty,
    required double actionability,
    required double userBurden,
  }) {
    final value = informationValueEngine.score(
      decisionRelevance: decisionRelevance,
      uncertainty: uncertainty,
      actionability: actionability,
      userBurden: userBurden,
    );
    if (hasUserLoggedToday) {
      return ZeroLogDecision(promptUser: false, reason: 'already_logged', informationValue: value);
    }
    if (hasPassiveDataToday && !value.shouldAsk) {
      return ZeroLogDecision(promptUser: false, reason: 'passive_data_sufficient', informationValue: value);
    }
    return ZeroLogDecision(
      promptUser: value.shouldAsk,
      reason: value.shouldAsk ? 'high_information_value' : 'not_worth_interrupting',
      informationValue: value,
    );
  }
}

class TimeMachineQuery {
  const TimeMachineQuery({
    required this.asOf,
    this.from,
    this.to,
    this.eventTypes = const <String>{},
  });

  final DateTime asOf;
  final DateTime? from;
  final DateTime? to;
  final Set<String> eventTypes;
}

class HealthDataTimeMachine {
  const HealthDataTimeMachine();

  List<HealthEvent> query(Iterable<HealthEvent> events, TimeMachineQuery query) {
    final result = events.where((event) {
      final knownAt = event.temporal.knownAt ?? event.temporal.recordedAt;
      if (knownAt.isAfter(query.asOf)) return false;
      if (query.eventTypes.isNotEmpty && !query.eventTypes.contains(event.eventType)) {
        return false;
      }
      if (query.from != null && event.temporal.observedAt.isBefore(query.from!)) {
        return false;
      }
      if (query.to != null && event.temporal.observedAt.isAfter(query.to!)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.temporal.observedAt.compareTo(b.temporal.observedAt));
    return List.unmodifiable(result);
  }
}
