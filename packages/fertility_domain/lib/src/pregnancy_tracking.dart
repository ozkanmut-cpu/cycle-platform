import 'package:cycle_core_domain/cycle_core_domain.dart';

import 'fertility_domain.dart';

class PregnancyTrackingValidationException implements Exception {
  const PregnancyTrackingValidationException(this.message);

  final String message;

  @override
  String toString() => 'PregnancyTrackingValidationException: $message';
}

class FetalMovementObservation {
  const FetalMovementObservation({
    required this.id,
    required this.observedAt,
    required this.state,
    required this.provenance,
  });

  final String id;
  final DateTime observedAt;
  final DataState state;
  final DomainProvenance provenance;
}

class KickCountSession {
  KickCountSession({
    required this.id,
    required this.pregnancyEpisodeId,
    required this.startedAt,
    required List<FetalMovementObservation> observations,
    this.endedAt,
    this.schemaVersion = 1,
  }) : observations = _validatedMovementOrder(observations) {
    _validateIds(this.observations.map((item) => item.id));
    if (id.trim().isEmpty || pregnancyEpisodeId.trim().isEmpty) {
      throw const PregnancyTrackingValidationException(
        'Session and pregnancy episode identifiers must not be blank.',
      );
    }
    if (schemaVersion <= 0) {
      throw const PregnancyTrackingValidationException(
        'Schema version must be positive.',
      );
    }
    if (endedAt != null && endedAt!.isBefore(startedAt)) {
      throw const PregnancyTrackingValidationException(
        'Kick-count session cannot end before it starts.',
      );
    }
    for (final observation in this.observations) {
      if (observation.observedAt.isBefore(startedAt) ||
          (endedAt != null && observation.observedAt.isAfter(endedAt!))) {
        throw const PregnancyTrackingValidationException(
          'Movement observation falls outside its session.',
        );
      }
      if (observation.provenance.sourceId.trim().isEmpty) {
        throw const PregnancyTrackingValidationException(
          'Movement provenance source id must not be blank.',
        );
      }
    }
  }

  final String id;
  final String pregnancyEpisodeId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int schemaVersion;
  final List<FetalMovementObservation> observations;

  int get explicitMovementCount => observations
      .where((observation) => observation.state == DataState.yes)
      .length;

  bool get hasIncompleteData => observations.any(
        (observation) =>
            observation.state == DataState.unknown ||
            observation.state == DataState.notRecorded,
      );
}

class ContractionObservation {
  const ContractionObservation({
    required this.id,
    required this.startedAt,
    required this.state,
    required this.provenance,
    this.endedAt,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DataState state;
  final DomainProvenance provenance;

  Duration? get duration =>
      endedAt == null ? null : endedAt!.difference(startedAt);
}

class ContractionTiming {
  const ContractionTiming({
    required this.observationId,
    required this.duration,
    required this.intervalFromPreviousStart,
  });

  final String observationId;
  final Duration? duration;
  final Duration? intervalFromPreviousStart;
}

class ContractionSessionSummary {
  const ContractionSessionSummary({
    required this.timings,
    required this.hasIncompleteData,
    required this.overlappingObservationIds,
  });

  final List<ContractionTiming> timings;
  final bool hasIncompleteData;
  final Set<String> overlappingObservationIds;
}

class ContractionSession {
  ContractionSession({
    required this.id,
    required this.pregnancyEpisodeId,
    required this.startedAt,
    required List<ContractionObservation> observations,
    this.endedAt,
    this.schemaVersion = 1,
  }) : observations = _validatedContractionOrder(observations) {
    _validateIds(this.observations.map((item) => item.id));
    if (id.trim().isEmpty || pregnancyEpisodeId.trim().isEmpty) {
      throw const PregnancyTrackingValidationException(
        'Session and pregnancy episode identifiers must not be blank.',
      );
    }
    if (schemaVersion <= 0) {
      throw const PregnancyTrackingValidationException(
        'Schema version must be positive.',
      );
    }
    if (endedAt != null && endedAt!.isBefore(startedAt)) {
      throw const PregnancyTrackingValidationException(
        'Contraction session cannot end before it starts.',
      );
    }
    for (final observation in this.observations) {
      if (observation.startedAt.isBefore(startedAt) ||
          (endedAt != null && observation.startedAt.isAfter(endedAt!))) {
        throw const PregnancyTrackingValidationException(
          'Contraction observation falls outside its session.',
        );
      }
      if (observation.endedAt != null &&
          observation.endedAt!.isBefore(observation.startedAt)) {
        throw const PregnancyTrackingValidationException(
          'Contraction cannot end before it starts.',
        );
      }
      if (endedAt != null &&
          observation.endedAt != null &&
          observation.endedAt!.isAfter(endedAt!)) {
        throw const PregnancyTrackingValidationException(
          'Contraction observation ends outside its session.',
        );
      }
      if (observation.provenance.sourceId.trim().isEmpty) {
        throw const PregnancyTrackingValidationException(
          'Contraction provenance source id must not be blank.',
        );
      }
    }
  }

  final String id;
  final String pregnancyEpisodeId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int schemaVersion;
  final List<ContractionObservation> observations;

  ContractionSessionSummary summarize() {
    DateTime? previousStart;
    final timings = <ContractionTiming>[];
    final overlaps = <String>{};
    final activeExplicit = <ContractionObservation>[];

    for (final observation in observations) {
      final interval = previousStart == null
          ? null
          : observation.startedAt.difference(previousStart);
      timings.add(
        ContractionTiming(
          observationId: observation.id,
          duration:
              observation.state == DataState.yes ? observation.duration : null,
          intervalFromPreviousStart:
              observation.state == DataState.yes ? interval : null,
        ),
      );

      if (observation.state == DataState.yes) {
        activeExplicit.removeWhere(
          (active) =>
              active.endedAt != null &&
              !active.endedAt!.isAfter(observation.startedAt),
        );
        for (final active in activeExplicit) {
          if (active.endedAt != null &&
              observation.startedAt.isBefore(active.endedAt!)) {
            overlaps
              ..add(active.id)
              ..add(observation.id);
          }
        }
        if (observation.endedAt != null) {
          activeExplicit.add(observation);
        }
        previousStart = observation.startedAt;
      }
    }

    return ContractionSessionSummary(
      timings: List.unmodifiable(timings),
      hasIncompleteData: observations.any(
        (observation) =>
            observation.state == DataState.unknown ||
            observation.state == DataState.notRecorded,
      ),
      overlappingObservationIds: Set.unmodifiable(overlaps),
    );
  }
}

void validateTrackingAgainstPregnancy({
  required PregnancyEpisode pregnancy,
  required DateTime sessionStartedAt,
  DateTime? sessionEndedAt,
}) {
  if (sessionEndedAt != null && sessionEndedAt.isBefore(sessionStartedAt)) {
    throw const PregnancyTrackingValidationException(
      'Tracking session cannot end before it starts.',
    );
  }
  if (sessionStartedAt.isBefore(pregnancy.startedAt) ||
      (pregnancy.endedAt != null &&
          sessionStartedAt.isAfter(pregnancy.endedAt!)) ||
      (sessionEndedAt != null &&
          pregnancy.endedAt != null &&
          sessionEndedAt.isAfter(pregnancy.endedAt!))) {
    throw const PregnancyTrackingValidationException(
      'Tracking session falls outside the pregnancy episode.',
    );
  }
}

void _validateIds(Iterable<String> ids) {
  final normalized = <String>{};
  for (final id in ids) {
    final key = id.trim().toLowerCase();
    if (key.isEmpty) {
      throw const PregnancyTrackingValidationException(
        'Observation identifiers must not be blank.',
      );
    }
    if (!normalized.add(key)) {
      throw PregnancyTrackingValidationException(
        'Duplicate observation identifier: $key',
      );
    }
  }
}

List<FetalMovementObservation> _validatedMovementOrder(
  List<FetalMovementObservation> observations,
) {
  DateTime? previous;
  for (final observation in observations) {
    if (previous != null && observation.observedAt.isBefore(previous)) {
      throw const PregnancyTrackingValidationException(
        'Movement observations must be supplied in chronological order.',
      );
    }
    previous = observation.observedAt;
  }
  final ordered = List<FetalMovementObservation>.from(observations)
    ..sort((a, b) {
      final byTime = a.observedAt.compareTo(b.observedAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  return List<FetalMovementObservation>.unmodifiable(ordered);
}

List<ContractionObservation> _validatedContractionOrder(
  List<ContractionObservation> observations,
) {
  DateTime? previous;
  for (final observation in observations) {
    if (previous != null && observation.startedAt.isBefore(previous)) {
      throw const PregnancyTrackingValidationException(
        'Contraction observations must be supplied in chronological order.',
      );
    }
    previous = observation.startedAt;
  }
  final ordered = List<ContractionObservation>.from(observations)
    ..sort((a, b) {
      final byTime = a.startedAt.compareTo(b.startedAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  return List<ContractionObservation>.unmodifiable(ordered);
}
