import 'dart:math' as math;

import 'package:cycle_core_domain/cycle_core_domain.dart';

enum IntelligenceUncertainty {
  known,
  unknown,
  estimated,
  conflicting,
  stale,
  incomplete,
  lowConfidence,
}

class IntelligenceValue {
  const IntelligenceValue({
    required this.state,
    this.value,
    this.reason,
  });

  final IntelligenceUncertainty state;
  final num? value;
  final String? reason;
}

class PersonalBaseline {
  const PersonalBaseline({
    required this.count,
    required this.mean,
    required this.median,
    required this.minimum,
    required this.maximum,
    required this.standardDeviation,
    required this.from,
    required this.to,
  });

  final int count;
  final double mean;
  final double median;
  final double minimum;
  final double maximum;
  final double standardDeviation;
  final DateTime from;
  final DateTime to;
}

class BaselineEngine {
  const BaselineEngine();

  PersonalBaseline? calculate(
    Iterable<HealthEvent> events, {
    required String eventType,
    required DateTime from,
    required DateTime to,
  }) {
    final selected = events
        .where(
          (event) =>
              event.eventType == eventType &&
              event.value != null &&
              !event.temporal.observedAt.isBefore(from) &&
              !event.temporal.observedAt.isAfter(to),
        )
        .map((event) => event.value!.toDouble())
        .toList()
      ..sort();
    if (selected.isEmpty) return null;

    final mean = selected.reduce((a, b) => a + b) / selected.length;
    final median = selected.length.isOdd
        ? selected[selected.length ~/ 2]
        : (selected[selected.length ~/ 2 - 1] + selected[selected.length ~/ 2]) /
            2;
    final variance = selected
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        selected.length;

    return PersonalBaseline(
      count: selected.length,
      mean: mean,
      median: median,
      minimum: selected.first,
      maximum: selected.last,
      standardDeviation: math.sqrt(variance),
      from: from,
      to: to,
    );
  }
}

enum TemporalDirection { increased, decreased, stable, insufficientData }

class TemporalComparison {
  const TemporalComparison({
    required this.direction,
    this.previousMean,
    this.currentMean,
    this.absoluteChange,
    this.percentChange,
  });

  final TemporalDirection direction;
  final double? previousMean;
  final double? currentMean;
  final double? absoluteChange;
  final double? percentChange;

  bool get changed =>
      direction == TemporalDirection.increased ||
      direction == TemporalDirection.decreased;
}

class TemporalEngine {
  const TemporalEngine({this.stableToleranceFraction = 0.05});

  final double stableToleranceFraction;

  TemporalComparison compare({
    required PersonalBaseline? previous,
    required PersonalBaseline? current,
  }) {
    if (previous == null || current == null) {
      return const TemporalComparison(
        direction: TemporalDirection.insufficientData,
      );
    }
    final change = current.mean - previous.mean;
    final percent = previous.mean == 0 ? null : change / previous.mean;
    final stable = percent == null
        ? change.abs() <= stableToleranceFraction
        : percent.abs() <= stableToleranceFraction;
    return TemporalComparison(
      direction: stable
          ? TemporalDirection.stable
          : change > 0
              ? TemporalDirection.increased
              : TemporalDirection.decreased,
      previousMean: previous.mean,
      currentMean: current.mean,
      absoluteChange: change,
      percentChange: percent,
    );
  }
}

class UncertaintyEngine {
  const UncertaintyEngine();

  IntelligenceValue classify({
    required HealthEvent? event,
    required DateTime now,
    Duration staleAfter = const Duration(days: 30),
    bool incompleteHistory = false,
    bool conflicting = false,
  }) {
    if (event == null) {
      return const IntelligenceValue(
        state: IntelligenceUncertainty.unknown,
        reason: 'No observation is available.',
      );
    }
    if (conflicting) {
      return IntelligenceValue(
        state: IntelligenceUncertainty.conflicting,
        value: event.value,
        reason: 'Multiple observations conflict.',
      );
    }
    if (incompleteHistory) {
      return IntelligenceValue(
        state: IntelligenceUncertainty.incomplete,
        value: event.value,
        reason: 'Available history is incomplete.',
      );
    }
    if (event.verificationStatus == VerificationStatus.estimated) {
      return IntelligenceValue(
        state: IntelligenceUncertainty.estimated,
        value: event.value,
      );
    }
    if (event.confidence == ConfidenceClass.low ||
        event.confidence == ConfidenceClass.unknown) {
      return IntelligenceValue(
        state: IntelligenceUncertainty.lowConfidence,
        value: event.value,
      );
    }
    if (now.difference(event.temporal.observedAt) > staleAfter) {
      return IntelligenceValue(
        state: IntelligenceUncertainty.stale,
        value: event.value,
      );
    }
    return IntelligenceValue(
      state: IntelligenceUncertainty.known,
      value: event.value,
    );
  }
}

class Contradiction {
  const Contradiction({required this.left, required this.right});

  final HealthEvent left;
  final HealthEvent right;
}

class ContradictionEngine {
  const ContradictionEngine();

  List<Contradiction> detect(
    Iterable<HealthEvent> events, {
    Duration coincidenceWindow = const Duration(minutes: 5),
    double numericTolerance = 0,
  }) {
    final sorted = events.toList()
      ..sort((a, b) => a.temporal.observedAt.compareTo(b.temporal.observedAt));
    final result = <Contradiction>[];
    for (var i = 0; i < sorted.length; i++) {
      for (var j = i + 1; j < sorted.length; j++) {
        final a = sorted[i];
        final b = sorted[j];
        if (a.subjectId != b.subjectId || a.eventType != b.eventType) continue;
        if (b.temporal.observedAt.difference(a.temporal.observedAt) >
            coincidenceWindow) {
          break;
        }
        final stateConflict = a.dataState != null &&
            b.dataState != null &&
            a.dataState != b.dataState &&
            a.dataState != DataState.unknown &&
            b.dataState != DataState.unknown;
        final numericConflict = a.value != null &&
            b.value != null &&
            (a.value!.toDouble() - b.value!.toDouble()).abs() >
                numericTolerance;
        if (stateConflict || numericConflict) {
          result.add(Contradiction(left: a, right: b));
        }
      }
    }
    return result;
  }
}

class InformationValueInput {
  const InformationValueInput({
    required this.decisionImpact,
    required this.uncertaintyReduction,
    required this.actionability,
    required this.userBurden,
    this.timeSensitivity = 0,
  });

  final double decisionImpact;
  final double uncertaintyReduction;
  final double actionability;
  final double userBurden;
  final double timeSensitivity;
}

class InformationValueEngine {
  const InformationValueEngine();

  double score(InformationValueInput input) {
    final benefit =
        input.decisionImpact * 0.35 +
        input.uncertaintyReduction * 0.3 +
        input.actionability * 0.2 +
        input.timeSensitivity * 0.15;
    return (benefit - input.userBurden * 0.25).clamp(0, 1).toDouble();
  }
}

class ZeroLogDecision {
  const ZeroLogDecision({
    required this.shouldPrompt,
    required this.informationValue,
    required this.reason,
  });

  final bool shouldPrompt;
  final double informationValue;
  final String reason;
}

class ZeroLogDayEngine {
  const ZeroLogDayEngine({this.promptThreshold = 0.45});

  final double promptThreshold;

  ZeroLogDecision decide({
    required bool hasMeaningfulDataToday,
    required InformationValueInput candidate,
    InformationValueEngine engine = const InformationValueEngine(),
  }) {
    if (hasMeaningfulDataToday) {
      return const ZeroLogDecision(
        shouldPrompt: false,
        informationValue: 0,
        reason: 'Meaningful data already exists today.',
      );
    }
    final value = engine.score(candidate);
    return ZeroLogDecision(
      shouldPrompt: value >= promptThreshold,
      informationValue: value,
      reason: value >= promptThreshold
          ? 'A prompt is likely to add meaningful information.'
          : 'Silence is more valuable than a low-value prompt.',
    );
  }
}

class TimeMachineQuery {
  const TimeMachineQuery({
    required this.subjectId,
    this.eventTypes = const <String>{},
    this.observedFrom,
    this.observedTo,
    this.knownBy,
  });

  final String subjectId;
  final Set<String> eventTypes;
  final DateTime? observedFrom;
  final DateTime? observedTo;
  final DateTime? knownBy;
}

class HealthDataTimeMachine {
  const HealthDataTimeMachine();

  List<HealthEvent> query(
    Iterable<HealthEvent> events,
    TimeMachineQuery query,
  ) {
    final result = events.where((event) {
      if (event.subjectId != query.subjectId) return false;
      if (query.eventTypes.isNotEmpty &&
          !query.eventTypes.contains(event.eventType)) {
        return false;
      }
      final observed = event.temporal.observedAt;
      if (query.observedFrom != null && observed.isBefore(query.observedFrom!)) {
        return false;
      }
      if (query.observedTo != null && observed.isAfter(query.observedTo!)) {
        return false;
      }
      if (query.knownBy != null) {
        final known = event.temporal.knownAt ??
            event.temporal.importedAt ??
            event.temporal.recordedAt;
        if (known.isAfter(query.knownBy!)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.temporal.observedAt.compareTo(b.temporal.observedAt));
    return result;
  }
}
