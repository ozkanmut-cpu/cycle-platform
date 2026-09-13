import 'package:cycle_core_domain/cycle_core_domain.dart';

import 'condition_pack.dart';

enum BleedingContext {
  menstrual,
  intermenstrual,
  postcoital,
  postmenopausal,
  other,
}

enum BleedingFlow { spotting, light, moderate, heavy }

enum BleedingFeature { clots, floodingGushing, frequentProtectionChange }

enum BleedingDescriptor {
  spotting,
  heavyFlow,
  prolonged,
  intermenstrual,
  postcoital,
  postmenopausal,
  conflicting,
  incomplete,
}

class BleedingObservation {
  const BleedingObservation({
    required this.id,
    required this.observedAt,
    required this.state,
    this.context,
    this.flow,
    this.features = const {},
    this.sourceId,
  });

  final String id;
  final DateTime observedAt;
  final DataState state;
  final BleedingContext? context;
  final BleedingFlow? flow;
  final Set<BleedingFeature> features;
  final String? sourceId;
}

class BleedingEpisode {
  const BleedingEpisode({
    required this.id,
    required this.startedAt,
    required this.observations,
    this.endedAt,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<BleedingObservation> observations;
}

class BleedingEvidenceRef {
  const BleedingEvidenceRef({
    required this.observationId,
    required this.observedAt,
    this.sourceId,
  });

  final String observationId;
  final DateTime observedAt;
  final String? sourceId;
}

class BleedingIntelligenceValidationException implements Exception {
  const BleedingIntelligenceValidationException(this.message);
  final String message;

  @override
  String toString() => 'BleedingIntelligenceValidationException: $message';
}

class BleedingIntelligenceResult {
  const BleedingIntelligenceResult({
    required this.descriptors,
    required this.symptomKeys,
    required this.evidence,
    required this.missingInformation,
  });

  final List<BleedingDescriptor> descriptors;
  final List<String> symptomKeys;
  final List<BleedingEvidenceRef> evidence;
  final Set<String> missingInformation;

  List<String> get evidenceObservationIds =>
      List.unmodifiable(evidence.map((item) => item.observationId));

  SymptomReport toSymptomReport() => SymptomReport(
        symptomKeys: symptomKeys.toSet(),
        unknownKeys: missingInformation,
      );
}

class BleedingIntelligenceEngine {
  const BleedingIntelligenceEngine({
    this.schemaVersion = 1,
    this.catalogVersion = '2026.1',
  });

  final int schemaVersion;
  final String catalogVersion;

  BleedingIntelligenceResult evaluate(BleedingEpisode episode) {
    if (schemaVersion <= 0 || catalogVersion.trim().isEmpty) {
      throw const BleedingIntelligenceValidationException(
        'Bleeding intelligence version metadata must be valid.',
      );
    }
    if (episode.id.trim().isEmpty || episode.observations.isEmpty) {
      throw const BleedingIntelligenceValidationException(
        'Bleeding episode needs an id and observations.',
      );
    }
    if (episode.endedAt != null &&
        episode.endedAt!.isBefore(episode.startedAt)) {
      throw const BleedingIntelligenceValidationException(
        'Bleeding episode cannot end before it starts.',
      );
    }

    final ids = <String>{};
    final descriptors = <BleedingDescriptor>{};
    final symptomKeys = <String>{};
    final evidence = <BleedingEvidenceRef>[];
    final missing = <String>{};
    final flowsByInstant = <DateTime, Set<BleedingFlow>>{};

    for (final observation in episode.observations) {
      final id = observation.id.trim().toLowerCase();
      if (id.isEmpty || !ids.add(id)) {
        throw BleedingIntelligenceValidationException(
          id.isEmpty
              ? 'Observation id must not be empty.'
              : 'Duplicate observation id: $id.',
        );
      }
      if (observation.sourceId != null &&
          observation.sourceId!.trim().isEmpty) {
        throw BleedingIntelligenceValidationException(
          'Observation "$id" has an empty source id.',
        );
      }
      if (observation.observedAt.isBefore(episode.startedAt) ||
          (episode.endedAt != null &&
              observation.observedAt.isAfter(episode.endedAt!))) {
        throw BleedingIntelligenceValidationException(
          'Observation "$id" is outside its episode.',
        );
      }

      if (observation.state == DataState.unknown ||
          observation.state == DataState.notRecorded) {
        if (observation.context != null ||
            observation.flow != null ||
            observation.features.isNotEmpty) {
          throw BleedingIntelligenceValidationException(
            'Unknown/not-recorded observation "$id" cannot contain bleeding details.',
          );
        }
        missing.add('bleeding observation');
        continue;
      }
      if (observation.state != DataState.yes) {
        throw BleedingIntelligenceValidationException(
          'Bleeding observation "$id" must be yes, unknown, or notRecorded.',
        );
      }

      evidence.add(
        BleedingEvidenceRef(
          observationId: id,
          observedAt: observation.observedAt,
          sourceId: observation.sourceId?.trim(),
        ),
      );

      if (observation.context == null) missing.add('bleeding context');
      if (observation.flow == null) missing.add('bleeding flow');
      final flow = observation.flow;
      if (flow != null) {
        flowsByInstant.putIfAbsent(observation.observedAt, () => {}).add(flow);
      }
      if (flow == BleedingFlow.spotting) {
        descriptors.add(BleedingDescriptor.spotting);
        symptomKeys.add('spotting');
      }
      if (flow == BleedingFlow.heavy ||
          observation.features.contains(BleedingFeature.floodingGushing) ||
          observation.features
              .contains(BleedingFeature.frequentProtectionChange)) {
        descriptors.add(BleedingDescriptor.heavyFlow);
        symptomKeys.add('heavy menstrual bleeding');
      }
      switch (observation.context) {
        case BleedingContext.intermenstrual:
          descriptors.add(BleedingDescriptor.intermenstrual);
          symptomKeys.add('intermenstrual bleeding');
        case BleedingContext.postcoital:
          descriptors.add(BleedingDescriptor.postcoital);
          symptomKeys.add('postcoital bleeding');
        case BleedingContext.postmenopausal:
          descriptors.add(BleedingDescriptor.postmenopausal);
          symptomKeys.add('postmenopausal bleeding');
        case BleedingContext.menstrual:
        case BleedingContext.other:
        case null:
          break;
      }
    }

    if (flowsByInstant.values.any((flows) => flows.length > 1)) {
      descriptors.add(BleedingDescriptor.conflicting);
    }
    if (episode.endedAt != null &&
        episode.endedAt!.difference(episode.startedAt).inHours >= 7 * 24) {
      descriptors.add(BleedingDescriptor.prolonged);
      symptomKeys.add('prolonged bleeding');
    }
    if (missing.isNotEmpty) descriptors.add(BleedingDescriptor.incomplete);

    final sortedDescriptors = descriptors.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final sortedSymptoms = symptomKeys.toList()..sort();
    evidence.sort((a, b) {
      final byTime = a.observedAt.compareTo(b.observedAt);
      if (byTime != 0) return byTime;
      return a.observationId.compareTo(b.observationId);
    });
    return BleedingIntelligenceResult(
      descriptors: List.unmodifiable(sortedDescriptors),
      symptomKeys: List.unmodifiable(sortedSymptoms),
      evidence: List.unmodifiable(evidence),
      missingInformation: Set.unmodifiable(missing),
    );
  }
}
