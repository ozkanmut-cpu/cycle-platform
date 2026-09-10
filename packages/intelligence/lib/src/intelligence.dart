import 'dart:math' as math;

import 'package:cycle_core_domain/cycle_core_domain.dart';

enum IntelligenceState {
  known,
  unknown,
  estimated,
  conflicting,
  stale,
  incomplete,
  lowConfidence,
}

class BaselineSummary {
  const BaselineSummary({
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

class BaselineEngine {
  const BaselineEngine();

  BaselineSummary? calculate({
    required Iterable<HealthEvent> events,
    required String eventType,
    required DateTime from,
    required DateTime to,
  }) {
    final values = events
        .where(
          (event) =>
              event.eventType == eventType &&
              event.value != null &&
              !event.temporal.observedAt.isBefore(from) &&
              event.temporal.observedAt.isBefore(to),
        )
        .map((event) => event.value!.toDouble())
        .toList()
      ..sort();
    if (values.isEmpty) return null;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
    final midpoint = values.length ~/ 2;
    final median = values.length.isOdd
        ? values[midpoint]
        : (values[midpoint - 1] + values[midpoint]) / 2;

    return BaselineSummary(
      eventType: eventType,
      count: values.length,
      mean: mean,
      median: median,
      minimum: values.first,
      maximum: values.last,
      standardDeviation: math.sqrt(variance),
      windowStart: from,
      windowEnd: to,
    );
  }
}

enum ChangeDirection { increased, decreased, unchanged }

class TemporalComparison {
  const TemporalComparison({
    required this.previous,
    required this.current,
    required this.absoluteChange,
    required this.relativeChange,
    required this.direction,
  });

  final BaselineSummary previous;
  final BaselineSummary current;
  final double absoluteChange;
  final double? relativeChange;
  final ChangeDirection direction;
}

class TemporalEngine {
  const TemporalEngine({this.epsilon = 1e-9});

  final double epsilon;

  TemporalComparison compare(
    BaselineSummary previous,
    BaselineSummary current,
  ) {
    final delta = current.mean - previous.mean;
    final relative =
        previous.mean.abs() <= epsilon ? null : delta / previous.mean.abs();
    final direction = delta.abs() <= epsilon
        ? ChangeDirection.unchanged
        : delta > 0
            ? ChangeDirection.increased
            : ChangeDirection.decreased;
    return TemporalComparison(
      previous: previous,
      current: current,
      absoluteChange: delta,
      relativeChange: relative,
      direction: direction,
    );
  }
}

class UncertaintyAssessment {
  const UncertaintyAssessment(this.states, {this.reasons = const []});

  final Set<IntelligenceState> states;
  final List<String> reasons;

  bool get isKnownOnly =>
      states.length == 1 && states.contains(IntelligenceState.known);
}

class UncertaintyEngine {
  const UncertaintyEngine({this.staleAfter = const Duration(days: 30)});

  final Duration staleAfter;

  UncertaintyAssessment assess({
    required HealthEvent? event,
    required DateTime now,
    bool incompleteHistory = false,
    bool conflicting = false,
  }) {
    if (event == null) {
      return const UncertaintyAssessment(
        {IntelligenceState.unknown},
        reasons: ['No canonical event is available.'],
      );
    }

    final states = <IntelligenceState>{};
    final reasons = <String>[];
    if (event.verificationStatus == VerificationStatus.estimated) {
      states.add(IntelligenceState.estimated);
      reasons.add('Value is estimated.');
    }
    if (event.confidence == ConfidenceClass.low ||
        event.confidence == ConfidenceClass.unknown) {
      states.add(IntelligenceState.lowConfidence);
      reasons.add('Confidence is low or unknown.');
    }
    if (now.difference(event.temporal.observedAt) > staleAfter) {
      states.add(IntelligenceState.stale);
      reasons.add('Latest observation is stale.');
    }
    if (incompleteHistory) {
      states.add(IntelligenceState.incomplete);
      reasons.add('Available history is incomplete.');
    }
    if (conflicting) {
      states.add(IntelligenceState.conflicting);
      reasons.add('Canonical evidence conflicts.');
    }
    if (event.dataState == DataState.unknown ||
        event.dataState == DataState.notRecorded) {
      states.add(IntelligenceState.unknown);
      reasons.add('State is unknown or not recorded.');
    }
    if (states.isEmpty) states.add(IntelligenceState.known);
    return UncertaintyAssessment(
      Set.unmodifiable(states),
      reasons: List.unmodifiable(reasons),
    );
  }
}

class Contradiction {
  const Contradiction({
    required this.left,
    required this.right,
    required this.reason,
  });

  final HealthEvent left;
  final HealthEvent right;
  final String reason;
}

class ContradictionEngine {
  const ContradictionEngine({this.numericTolerance = 0});

  final double numericTolerance;

  List<Contradiction> detect(Iterable<HealthEvent> events) {
    final sorted = events.toList()
      ..sort((a, b) => a.temporal.observedAt.compareTo(b.temporal.observedAt));
    final output = <Contradiction>[];
    for (var i = 0; i < sorted.length; i++) {
      for (var j = i + 1; j < sorted.length; j++) {
        final a = sorted[i];
        final b = sorted[j];
        if (a.subjectId != b.subjectId || a.eventType != b.eventType) continue;
        if (a.temporal.observedAt != b.temporal.observedAt) continue;
        final numericConflict = a.value != null &&
            b.value != null &&
            (a.value!.toDouble() - b.value!.toDouble()).abs() >
                numericTolerance;
        final stateConflict = a.dataState != null &&
            b.dataState != null &&
            a.dataState != b.dataState &&
            {a.dataState, b.dataState}.contains(DataState.yes) &&
            {a.dataState, b.dataState}.contains(DataState.no);
        if (numericConflict || stateConflict) {
          output.add(
            Contradiction(
              left: a,
              right: b,
              reason: numericConflict
                  ? 'Conflicting numeric values.'
                  : 'Conflicting yes/no states.',
            ),
          );
        }
      }
    }
    return List.unmodifiable(output);
  }
}

class InformationValueResult {
  const InformationValueResult({
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

  InformationValueResult evaluate({
    required UncertaintyAssessment uncertainty,
    required double decisionImpact,
    required double userBurden,
  }) {
    final uncertaintyWeight = uncertainty.isKnownOnly
        ? 0.0
        : math.min(1.0, uncertainty.states.length / 3);
    final impact = decisionImpact.clamp(0.0, 1.0);
    final burden = userBurden.clamp(0.0, 1.0);
    final score = (uncertaintyWeight * 0.5) + (impact * 0.5) - (burden * 0.4);
    final normalized = score.clamp(0.0, 1.0).toDouble();
    return InformationValueResult(
      score: normalized,
      shouldAsk: normalized >= askThreshold,
      reasons: [
        'uncertainty=${uncertaintyWeight.toStringAsFixed(2)}',
        'impact=${impact.toStringAsFixed(2)}',
        'burden=${burden.toStringAsFixed(2)}',
      ],
    );
  }
}

class ZeroLogDecision {
  const ZeroLogDecision({required this.shouldPrompt, required this.reason});

  final bool shouldPrompt;
  final String reason;
}

class ZeroLogDayEngine {
  const ZeroLogDayEngine();

  ZeroLogDecision decide({
    required bool userLoggedToday,
    required bool passiveDataPresent,
    required InformationValueResult informationValue,
  }) {
    if (userLoggedToday) {
      return const ZeroLogDecision(
        shouldPrompt: false,
        reason: 'User already logged today.',
      );
    }
    if (passiveDataPresent && !informationValue.shouldAsk) {
      return const ZeroLogDecision(
        shouldPrompt: false,
        reason: 'Passive data is sufficient and asking adds little value.',
      );
    }
    if (!informationValue.shouldAsk) {
      return const ZeroLogDecision(
        shouldPrompt: false,
        reason: 'Expected information value is below threshold.',
      );
    }
    return const ZeroLogDecision(
      shouldPrompt: true,
      reason: 'A low-burden prompt is expected to add meaningful information.',
    );
  }
}

class HealthDataTimeMachine {
  const HealthDataTimeMachine();

  List<HealthEvent> between(
    Iterable<HealthEvent> events, {
    required DateTime from,
    required DateTime to,
    String? eventType,
  }) {
    final result = events.where((event) {
      final observedAt = event.temporal.observedAt;
      return !observedAt.isBefore(from) &&
          observedAt.isBefore(to) &&
          (eventType == null || event.eventType == eventType);
    }).toList()
      ..sort((a, b) => a.temporal.observedAt.compareTo(b.temporal.observedAt));
    return List.unmodifiable(result);
  }

  HealthEvent? latestBefore(
    Iterable<HealthEvent> events, {
    required DateTime at,
    required String eventType,
  }) {
    final candidates = events
        .where(
          (event) =>
              event.eventType == eventType &&
              !event.temporal.observedAt.isAfter(at),
        )
        .toList()
      ..sort((a, b) => b.temporal.observedAt.compareTo(a.temporal.observedAt));
    return candidates.isEmpty ? null : candidates.first;
  }
}
