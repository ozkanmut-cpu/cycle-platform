import 'package:cycle_core_domain/cycle_core_domain.dart';

import 'ai_runtime.dart';

enum LearnedFactOrigin { explicit, derived }

enum LearnedFactLifecycle { active, stale, expired, conflicted }

class LearnedAboutMeValidationException implements Exception {
  const LearnedAboutMeValidationException(this.message);
  final String message;
  @override
  String toString() => 'LearnedAboutMeValidationException: $message';
}

class LearnedFactCandidate {
  LearnedFactCandidate({
    required this.id,
    required this.patientId,
    required this.key,
    required this.state,
    required this.origin,
    required this.confidence,
    required this.provenance,
    required this.learnedAt,
    this.value,
    Iterable<String> evidenceIds = const <String>[],
    this.expiresAt,
    this.schemaVersion = 1,
  }) : evidenceIds = List<String>.unmodifiable(evidenceIds) {
    _validateCandidate(this);
  }

  final String id;
  final String patientId;
  final String key;
  final String? value;
  final DataState state;
  final LearnedFactOrigin origin;
  final ConfidenceClass confidence;
  final Provenance provenance;
  final List<String> evidenceIds;
  final DateTime learnedAt;
  final DateTime? expiresAt;
  final int schemaVersion;
}

class LearnedFact {
  LearnedFact({
    required this.id,
    required this.patientId,
    required this.key,
    required this.state,
    required this.origin,
    required this.confidence,
    required Iterable<Provenance> provenances,
    required Iterable<String> evidenceIds,
    required this.learnedAt,
    required this.lifecycle,
    this.value,
    this.schemaVersion = 1,
  })  : provenances = List<Provenance>.unmodifiable(provenances),
        evidenceIds = List<String>.unmodifiable(evidenceIds);

  final String id;
  final String patientId;
  final String key;
  final String? value;
  final DataState state;
  final LearnedFactOrigin origin;
  final ConfidenceClass confidence;
  final List<Provenance> provenances;
  final List<String> evidenceIds;
  final DateTime learnedAt;
  final LearnedFactLifecycle lifecycle;
  final int schemaVersion;

  bool get hasResolvedValue => lifecycle != LearnedFactLifecycle.conflicted;
}

class LearnedAboutMeProfile {
  LearnedAboutMeProfile({
    required this.patientId,
    required Iterable<LearnedFact> facts,
    this.schemaVersion = 1,
  }) : facts = List<LearnedFact>.unmodifiable(facts);

  final String patientId;
  final List<LearnedFact> facts;
  final int schemaVersion;
}

class LearnedAboutMeReconciler {
  const LearnedAboutMeReconciler();

  LearnedAboutMeProfile reconcile({
    required Iterable<LearnedFactCandidate> candidates,
    required DateTime asOf,
    Duration staleAfter = const Duration(days: 90),
  }) {
    final input = candidates.toList();
    if (input.isEmpty) {
      throw const LearnedAboutMeValidationException(
        'At least one learned fact candidate is required.',
      );
    }
    final patients = input.map((item) => item.patientId.trim()).toSet();
    if (patients.length != 1) {
      throw const LearnedAboutMeValidationException(
        'Learned facts cannot mix patients.',
      );
    }
    if (staleAfter.isNegative) {
      throw const LearnedAboutMeValidationException(
        'Stale interval must not be negative.',
      );
    }

    final groups = <String, List<LearnedFactCandidate>>{};
    for (final item in input) {
      groups.putIfAbsent(_normalizedKey(item.key), () => []).add(item);
    }
    final keys = groups.keys.toList()..sort();
    final facts = <LearnedFact>[];
    for (final key in keys) {
      facts.add(_reconcileGroup(groups[key]!, asOf.toUtc(), staleAfter));
    }
    return LearnedAboutMeProfile(
      patientId: patients.single,
      facts: facts,
    );
  }

  LearnedFact _reconcileGroup(
    List<LearnedFactCandidate> group,
    DateTime asOf,
    Duration staleAfter,
  ) {
    group.sort((a, b) {
      final byTime = a.learnedAt.compareTo(b.learnedAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    final latest = group.last;
    final knownIdentities = group
        .where((item) => !_isMissing(item.state))
        .map((item) => '${item.state.name}|${item.value ?? ''}')
        .toSet();
    final conflicted = knownIdentities.length > 1;
    final allExpired = group.every(
      (item) => item.expiresAt != null && !item.expiresAt!.isAfter(asOf),
    );
    final stale = asOf.difference(latest.learnedAt.toUtc()) > staleAfter;
    final lifecycle = conflicted
        ? LearnedFactLifecycle.conflicted
        : allExpired
            ? LearnedFactLifecycle.expired
            : stale
                ? LearnedFactLifecycle.stale
                : LearnedFactLifecycle.active;

    final evidence = group.expand((item) => item.evidenceIds).toSet().toList()
      ..sort();
    final provenances = group.map((item) => item.provenance).toList()
      ..sort(
        (a, b) => _provenanceIdentity(a).compareTo(_provenanceIdentity(b)),
      );
    final origin = group.any((item) => item.origin == LearnedFactOrigin.derived)
        ? LearnedFactOrigin.derived
        : LearnedFactOrigin.explicit;
    final confidence = _lowestConfidence(group.map((item) => item.confidence));

    return LearnedFact(
      id: _stableFactId(latest.patientId, _normalizedKey(latest.key)),
      patientId: latest.patientId.trim(),
      key: _normalizedKey(latest.key),
      value: conflicted ? null : latest.value,
      state: conflicted ? DataState.unknown : latest.state,
      origin: origin,
      confidence: conflicted ? ConfidenceClass.unknown : confidence,
      provenances: provenances,
      evidenceIds: evidence,
      learnedAt: latest.learnedAt.toUtc(),
      lifecycle: lifecycle,
    );
  }
}

class LearnedAboutMeContextProjector {
  const LearnedAboutMeContextProjector({
    this.firewall = const AiContextFirewall(),
  });

  final AiContextFirewall firewall;

  AiContextFirewallResult project({
    required LearnedAboutMeProfile profile,
    required AiContextPolicy policy,
  }) {
    final context = <String, Object?>{};
    for (final fact in profile.facts) {
      context[fact.key] = <String, Object?>{
        'value': fact.value,
        'dataState': fact.state.name,
        'confidence': fact.confidence.name,
        'lifecycle': fact.lifecycle.name,
        'evidenceIds': fact.evidenceIds,
      };
    }
    return firewall.filter(context: context, policy: policy);
  }
}

void _validateCandidate(LearnedFactCandidate candidate) {
  if (candidate.id.trim().isEmpty ||
      candidate.patientId.trim().isEmpty ||
      candidate.key.trim().isEmpty) {
    throw const LearnedAboutMeValidationException(
      'Learned fact identifiers, patient and key must not be blank.',
    );
  }
  if (candidate.schemaVersion <= 0) {
    throw const LearnedAboutMeValidationException(
      'Schema version must be positive.',
    );
  }
  if (candidate.origin == LearnedFactOrigin.derived &&
      candidate.evidenceIds.isEmpty) {
    throw const LearnedAboutMeValidationException(
      'Derived learned facts require evidence.',
    );
  }
  if (candidate.evidenceIds.any((id) => id.trim().isEmpty)) {
    throw const LearnedAboutMeValidationException(
      'Evidence identifiers must not be blank.',
    );
  }
  if (candidate.expiresAt != null &&
      candidate.expiresAt!.isBefore(candidate.learnedAt)) {
    throw const LearnedAboutMeValidationException(
      'Learned fact expiry cannot precede learning time.',
    );
  }
  if (!_isMissing(candidate.state) &&
      (candidate.value == null || candidate.value!.trim().isEmpty)) {
    throw const LearnedAboutMeValidationException(
      'Known learned facts require an explicit value.',
    );
  }
  if (_isMissing(candidate.state) && candidate.value != null) {
    throw const LearnedAboutMeValidationException(
      'Missing learned facts must not invent a value.',
    );
  }
}

bool _isMissing(DataState state) =>
    state == DataState.unknown || state == DataState.notRecorded;

String _normalizedKey(String key) => key.trim().toLowerCase();

String _stableFactId(String patientId, String key) =>
    '${patientId.trim()}::$key';

String _provenanceIdentity(Provenance provenance) => [
      provenance.sourceKind.name,
      provenance.sourceId ?? '',
      provenance.sourceRecordId ?? '',
      provenance.sourceName ?? '',
    ].join('|');

ConfidenceClass _lowestConfidence(Iterable<ConfidenceClass> values) {
  const rank = <ConfidenceClass, int>{
    ConfidenceClass.high: 4,
    ConfidenceClass.medium: 3,
    ConfidenceClass.low: 2,
    ConfidenceClass.contextual: 1,
    ConfidenceClass.unknown: 0,
  };
  return values.reduce(
    (a, b) => rank[a]! <= rank[b]! ? a : b,
  );
}
