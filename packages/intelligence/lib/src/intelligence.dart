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
    this.subjectId,
  });

  final String? subjectId;
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
    String? subjectId,
  }) {
    if (!from.isBefore(to)) {
      throw ArgumentError.value(
        <DateTime>[from, to],
        'window',
        'Baseline window must have from < to.',
      );
    }

    final values = events
        .where(
          (event) =>
              event.eventType == eventType &&
              (subjectId == null || event.subjectId == subjectId) &&
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
      subjectId: subjectId,
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

  BaselineSummary? calculatePersonal({
    required Iterable<HealthEvent> events,
    required String subjectId,
    required String eventType,
    required DateTime from,
    required DateTime to,
  }) =>
      calculate(
        events: events,
        subjectId: subjectId,
        eventType: eventType,
        from: from,
        to: to,
      );
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

class ChangeDetectionPolicy {
  const ChangeDetectionPolicy({
    this.minimumAbsoluteChange = 0,
    this.minimumRelativeChange = 0,
  });

  final double minimumAbsoluteChange;
  final double minimumRelativeChange;

  bool isMeaningful(TemporalComparison comparison) {
    final absolutePass =
        comparison.absoluteChange.abs() >= minimumAbsoluteChange;
    final relative = comparison.relativeChange;
    final relativePass =
        relative != null && relative.abs() >= minimumRelativeChange;
    return absolutePass && relativePass;
  }
}

class ChangeSignal {
  const ChangeSignal({
    required this.comparison,
    required this.meaningful,
    required this.reasons,
  });

  final TemporalComparison comparison;
  final bool meaningful;
  final List<String> reasons;
}

typedef ChangeDetectionHook = void Function(ChangeSignal signal);

class TemporalEngine {
  const TemporalEngine({this.epsilon = 1e-9});

  final double epsilon;

  TemporalComparison compare(
    BaselineSummary previous,
    BaselineSummary current,
  ) {
    if (previous.eventType != current.eventType) {
      throw ArgumentError(
          'Cannot compare baselines for different event types.');
    }
    if (previous.subjectId != null &&
        current.subjectId != null &&
        previous.subjectId != current.subjectId) {
      throw ArgumentError('Cannot compare baselines for different subjects.');
    }

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

  ChangeSignal detectChange(
    BaselineSummary previous,
    BaselineSummary current, {
    ChangeDetectionPolicy policy = const ChangeDetectionPolicy(),
    Iterable<ChangeDetectionHook> hooks = const <ChangeDetectionHook>[],
  }) {
    final comparison = compare(previous, current);
    final meaningful = policy.isMeaningful(comparison);
    final reasons = <String>[
      'direction=${comparison.direction.name}',
      'absolute=${comparison.absoluteChange.toStringAsFixed(6)}',
      'relative=${comparison.relativeChange?.toStringAsFixed(6) ?? 'undefined'}',
      'meaningful=$meaningful',
    ];
    final signal = ChangeSignal(
      comparison: comparison,
      meaningful: meaningful,
      reasons: List.unmodifiable(reasons),
    );
    for (final hook in hooks) {
      hook(signal);
    }
    return signal;
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
    final states = <IntelligenceState>{};
    final reasons = <String>[];

    if (event == null) {
      states.add(IntelligenceState.unknown);
      reasons.add('No canonical event is available.');
    } else {
      if (event.verificationStatus == VerificationStatus.estimated) {
        states.add(IntelligenceState.estimated);
        reasons.add('Value is estimated.');
      }
      if (event.confidence == ConfidenceClass.low ||
          event.confidence == ConfidenceClass.unknown) {
        states.add(IntelligenceState.lowConfidence);
        reasons.add('Confidence is low or unknown.');
      }
      final age = now.toUtc().difference(event.temporal.observedAt.toUtc());
      if (!age.isNegative && age > staleAfter) {
        states.add(IntelligenceState.stale);
        reasons.add('Latest observation is stale.');
      }
      if (event.dataState == DataState.unknown ||
          event.dataState == DataState.notRecorded ||
          (event.value == null && event.dataState == null)) {
        states.add(IntelligenceState.unknown);
        reasons.add('State is unknown or not recorded.');
      }
    }

    if (incompleteHistory) {
      states.add(IntelligenceState.incomplete);
      reasons.add('Available history is incomplete.');
    }
    if (conflicting) {
      states.add(IntelligenceState.conflicting);
      reasons.add('Canonical evidence conflicts.');
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
  const ContradictionEngine({
    this.numericTolerance = 0,
    this.sameMomentTolerance = Duration.zero,
  });

  final double numericTolerance;
  final Duration sameMomentTolerance;

  bool contradicts(HealthEvent a, HealthEvent b) {
    if (a.subjectId != b.subjectId || a.eventType != b.eventType) return false;
    if (a.temporal.observedAt.difference(b.temporal.observedAt).abs() >
        sameMomentTolerance) {
      return false;
    }

    final numericConflict = a.value != null &&
        b.value != null &&
        (a.value!.toDouble() - b.value!.toDouble()).abs() > numericTolerance;
    final states = {a.dataState, b.dataState};
    final stateConflict =
        states.contains(DataState.yes) && states.contains(DataState.no);
    return numericConflict || stateConflict;
  }

  List<Contradiction> detect(Iterable<HealthEvent> events) {
    final sorted = events.toList()
      ..sort((a, b) {
        final byTime = a.temporal.observedAt.compareTo(b.temporal.observedAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final output = <Contradiction>[];
    for (var i = 0; i < sorted.length; i++) {
      for (var j = i + 1; j < sorted.length; j++) {
        final a = sorted[i];
        final b = sorted[j];
        if (!contradicts(a, b)) continue;

        final numericConflict = a.value != null &&
            b.value != null &&
            (a.value!.toDouble() - b.value!.toDouble()).abs() >
                numericTolerance;
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
    final impact = decisionImpact.clamp(0.0, 1.0).toDouble();
    final burden = userBurden.clamp(0.0, 1.0).toDouble();
    final rawScore =
        (uncertaintyWeight * 0.5) + (impact * 0.5) - (burden * 0.4);
    final score = rawScore.clamp(0.0, 1.0).toDouble();
    return InformationValueResult(
      score: score,
      shouldAsk: score >= askThreshold,
      reasons: List.unmodifiable([
        'uncertainty=${uncertaintyWeight.toStringAsFixed(2)}',
        'impact=${impact.toStringAsFixed(2)}',
        'burden=${burden.toStringAsFixed(2)}',
      ]),
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
    String? subjectId,
  }) {
    if (!from.isBefore(to)) {
      throw ArgumentError.value(
        <DateTime>[from, to],
        'window',
        'Query window must have from < to.',
      );
    }
    final result = events.where((event) {
      final observedAt = event.temporal.observedAt;
      return !observedAt.isBefore(from) &&
          observedAt.isBefore(to) &&
          (eventType == null || event.eventType == eventType) &&
          (subjectId == null || event.subjectId == subjectId);
    }).toList()
      ..sort(_eventOrder);
    return List.unmodifiable(result);
  }

  List<HealthEvent> knownAsOf(
    Iterable<HealthEvent> events, {
    required DateTime asOf,
    String? eventType,
    String? subjectId,
  }) {
    final result = events.where((event) {
      final knownAt = event.temporal.knownAt ?? event.temporal.recordedAt;
      return !knownAt.isAfter(asOf) &&
          (eventType == null || event.eventType == eventType) &&
          (subjectId == null || event.subjectId == subjectId);
    }).toList()
      ..sort(_eventOrder);
    return List.unmodifiable(result);
  }

  List<HealthEvent> snapshotAsOf(
    Iterable<HealthEvent> events, {
    required DateTime asOf,
    String? eventType,
    String? subjectId,
  }) {
    final result = knownAsOf(
      events,
      asOf: asOf,
      eventType: eventType,
      subjectId: subjectId,
    ).where((event) => !event.temporal.observedAt.isAfter(asOf)).toList()
      ..sort(_eventOrder);
    return List.unmodifiable(result);
  }

  HealthEvent? latestBefore(
    Iterable<HealthEvent> events, {
    required DateTime at,
    required String eventType,
    String? subjectId,
  }) {
    final candidates = events
        .where(
          (event) =>
              event.eventType == eventType &&
              (subjectId == null || event.subjectId == subjectId) &&
              !event.temporal.observedAt.isAfter(at),
        )
        .toList()
      ..sort((a, b) {
        final byTime = b.temporal.observedAt.compareTo(a.temporal.observedAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return candidates.isEmpty ? null : candidates.first;
  }

  static int _eventOrder(HealthEvent a, HealthEvent b) {
    final byTime = a.temporal.observedAt.compareTo(b.temporal.observedAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }
}
