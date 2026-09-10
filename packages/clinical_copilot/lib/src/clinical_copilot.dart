import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_intelligence/cycle_intelligence.dart';

enum SnapshotSectionKind {
  whatChanged,
  whatMatters,
  missing,
  uncertain,
  conflicts,
  openLoops,
}

enum EvidenceNodeKind { event, document, inference, question, action }

enum ClinicalWriteDisposition { proposed, approved, rejected }

enum ReviewDecision { pending, approved, rejected }

enum StructuredQueryKind {
  latest,
  between,
  knownAsOf,
  changedSince,
  conflicts,
  missing,
}

class DoctorPatient {
  const DoctorPatient({
    required this.id,
    required this.displayName,
    this.dateOfBirth,
    this.tags = const <String>[],
  });

  final String id;
  final String displayName;
  final DateTime? dateOfBirth;
  final List<String> tags;
}

class SnapshotItem {
  const SnapshotItem({
    required this.id,
    required this.title,
    required this.detail,
    required this.evidenceIds,
    this.priority = 0,
  });

  final String id;
  final String title;
  final String detail;
  final List<String> evidenceIds;
  final int priority;
}

class ClinicalSnapshot {
  ClinicalSnapshot({
    required this.patientId,
    required this.generatedAt,
    required Map<SnapshotSectionKind, List<SnapshotItem>> sections,
  }) : sections = Map.unmodifiable(
          sections.map(
            (key, value) =>
                MapEntry(key, List<SnapshotItem>.unmodifiable(value)),
          ),
        );

  final String patientId;
  final DateTime generatedAt;
  final Map<SnapshotSectionKind, List<SnapshotItem>> sections;

  List<SnapshotItem> section(SnapshotSectionKind kind) =>
      sections[kind] ?? const <SnapshotItem>[];
}

class EvidenceNode {
  const EvidenceNode({
    required this.id,
    required this.kind,
    required this.label,
    required this.sourceId,
    required this.confidence,
  });

  final String id;
  final EvidenceNodeKind kind;
  final String label;
  final String sourceId;
  final double confidence;
}

class EvidenceEdge {
  const EvidenceEdge({
    required this.fromId,
    required this.toId,
    required this.relationship,
  });

  final String fromId;
  final String toId;
  final String relationship;
}

class EvidenceGraph {
  EvidenceGraph({
    required List<EvidenceNode> nodes,
    required List<EvidenceEdge> edges,
  })  : nodes = List<EvidenceNode>.unmodifiable(nodes),
        edges = List<EvidenceEdge>.unmodifiable(edges);

  final List<EvidenceNode> nodes;
  final List<EvidenceEdge> edges;

  Iterable<EvidenceNode> evidenceFor(String targetId) {
    final ids = edges
        .where((edge) => edge.toId == targetId)
        .map((edge) => edge.fromId)
        .toSet();
    return nodes.where((node) => ids.contains(node.id));
  }
}

class ClinicalCompressionResult {
  ClinicalCompressionResult({
    required this.summary,
    required this.graph,
    required List<String> evidenceIds,
  }) : evidenceIds = List<String>.unmodifiable(evidenceIds);

  final String summary;
  final EvidenceGraph graph;
  final List<String> evidenceIds;
}

class ClinicalCompressionEngine {
  const ClinicalCompressionEngine();

  ClinicalCompressionResult compress({
    required String patientId,
    required Iterable<SnapshotItem> items,
  }) {
    final sorted = items.toList()
      ..sort((a, b) {
        final priority = b.priority.compareTo(a.priority);
        return priority != 0 ? priority : a.id.compareTo(b.id);
      });
    final evidenceIds = <String>{};
    final nodes = <EvidenceNode>[];
    final edges = <EvidenceEdge>[];
    for (final item in sorted) {
      nodes.add(
        EvidenceNode(
          id: 'summary-${item.id}',
          kind: EvidenceNodeKind.inference,
          label: item.title,
          sourceId: patientId,
          confidence: 1,
        ),
      );
      for (final evidenceId in item.evidenceIds) {
        evidenceIds.add(evidenceId);
        nodes.add(
          EvidenceNode(
            id: 'evidence-$evidenceId',
            kind: EvidenceNodeKind.event,
            label: evidenceId,
            sourceId: evidenceId,
            confidence: 1,
          ),
        );
        edges.add(
          EvidenceEdge(
            fromId: 'evidence-$evidenceId',
            toId: 'summary-${item.id}',
            relationship: 'supports',
          ),
        );
      }
    }
    final uniqueNodes = <String, EvidenceNode>{
      for (final node in nodes) node.id: node,
    }.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    edges.sort((a, b) {
      final from = a.fromId.compareTo(b.fromId);
      return from != 0 ? from : a.toId.compareTo(b.toId);
    });
    final summary = sorted.map((item) => item.title).join(' · ');
    return ClinicalCompressionResult(
      summary: summary,
      graph: EvidenceGraph(nodes: uniqueNodes, edges: edges),
      evidenceIds: evidenceIds.toList()..sort(),
    );
  }
}

class StructuredRecordQuery {
  const StructuredRecordQuery({
    required this.kind,
    required this.patientId,
    this.eventType,
    this.from,
    this.to,
    this.asOf,
  });

  final StructuredQueryKind kind;
  final String patientId;
  final String? eventType;
  final DateTime? from;
  final DateTime? to;
  final DateTime? asOf;
}

class SafeRecordQueryRouter {
  const SafeRecordQueryRouter();

  StructuredRecordQuery route({
    required String patientId,
    required String naturalLanguage,
    required DateTime now,
  }) {
    final text = naturalLanguage.toLowerCase().trim();
    if (text.contains('conflict') || text.contains('çeliş')) {
      return StructuredRecordQuery(
        kind: StructuredQueryKind.conflicts,
        patientId: patientId,
      );
    }
    if (text.contains('missing') || text.contains('eksik')) {
      return StructuredRecordQuery(
        kind: StructuredQueryKind.missing,
        patientId: patientId,
      );
    }
    if (text.contains('known as of') || text.contains('o tarihte bilinen')) {
      return StructuredRecordQuery(
        kind: StructuredQueryKind.knownAsOf,
        patientId: patientId,
        asOf: now.toUtc(),
      );
    }
    if (text.contains('changed') || text.contains('değiş')) {
      return StructuredRecordQuery(
        kind: StructuredQueryKind.changedSince,
        patientId: patientId,
        from: now.toUtc().subtract(const Duration(days: 30)),
        to: now.toUtc(),
      );
    }
    if (text.contains('last 7 days') || text.contains('son 7 gün')) {
      return StructuredRecordQuery(
        kind: StructuredQueryKind.between,
        patientId: patientId,
        from: now.toUtc().subtract(const Duration(days: 7)),
        to: now.toUtc(),
      );
    }
    return StructuredRecordQuery(
      kind: StructuredQueryKind.latest,
      patientId: patientId,
      asOf: now.toUtc(),
    );
  }
}

class ReasoningNote {
  ReasoningNote({
    required this.id,
    required this.patientId,
    required this.authorId,
    required this.text,
    required List<String> evidenceIds,
    required this.createdAt,
  }) : evidenceIds = List<String>.unmodifiable(evidenceIds);

  final String id;
  final String patientId;
  final String authorId;
  final String text;
  final List<String> evidenceIds;
  final DateTime createdAt;
}

class ClinicalReasoningWorkspace {
  ClinicalReasoningWorkspace({Iterable<ReasoningNote> notes = const []})
      : _notes = List<ReasoningNote>.of(notes);

  final List<ReasoningNote> _notes;

  List<ReasoningNote> forPatient(String patientId) {
    final output = _notes.where((note) => note.patientId == patientId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(output);
  }

  void add(ReasoningNote note) => _notes.add(note);
}

class ProposedClinicalWrite {
  const ProposedClinicalWrite({
    required this.id,
    required this.patientId,
    required this.actionType,
    required this.payload,
    required this.evidenceIds,
    this.disposition = ClinicalWriteDisposition.proposed,
  });

  final String id;
  final String patientId;
  final String actionType;
  final Map<String, Object?> payload;
  final List<String> evidenceIds;
  final ClinicalWriteDisposition disposition;
}

class DoctorReviewRecord {
  const DoctorReviewRecord({
    required this.proposalId,
    required this.reviewerId,
    required this.decision,
    required this.reviewedAt,
    this.note,
  });

  final String proposalId;
  final String reviewerId;
  final ReviewDecision decision;
  final DateTime reviewedAt;
  final String? note;
}

class DoctorReviewGate {
  const DoctorReviewGate();

  bool canCommit(ProposedClinicalWrite proposal, DoctorReviewRecord? review) {
    return review != null &&
        review.proposalId == proposal.id &&
        review.decision == ReviewDecision.approved;
  }

  ProposedClinicalWrite approve(
    ProposedClinicalWrite proposal,
    DoctorReviewRecord review,
  ) {
    if (!canCommit(proposal, review)) {
      throw StateError('Clinical write requires explicit doctor approval.');
    }
    return ProposedClinicalWrite(
      id: proposal.id,
      patientId: proposal.patientId,
      actionType: proposal.actionType,
      payload: Map.unmodifiable(proposal.payload),
      evidenceIds: List.unmodifiable(proposal.evidenceIds),
      disposition: ClinicalWriteDisposition.approved,
    );
  }
}

class TreatmentTrialHook {
  const TreatmentTrialHook({
    required this.id,
    required this.patientId,
    required this.hypothesis,
    required this.startAt,
    required this.endAt,
    required this.outcomeEventTypes,
  });

  final String id;
  final String patientId;
  final String hypothesis;
  final DateTime startAt;
  final DateTime endAt;
  final List<String> outcomeEventTypes;
}

class ClinicalQuestionProtocolHook {
  const ClinicalQuestionProtocolHook({
    required this.id,
    required this.patientId,
    required this.question,
    required this.requiredEvidenceTypes,
  });

  final String id;
  final String patientId;
  final String question;
  final List<String> requiredEvidenceTypes;
}

class AiOutputAuditRecord {
  AiOutputAuditRecord({
    required this.id,
    required this.patientId,
    required this.modelId,
    required this.promptPurpose,
    required this.output,
    required List<String> evidenceIds,
    required this.generatedAt,
    required this.requiresDoctorReview,
  }) : evidenceIds = List<String>.unmodifiable(evidenceIds);

  final String id;
  final String patientId;
  final String modelId;
  final String promptPurpose;
  final String output;
  final List<String> evidenceIds;
  final DateTime generatedAt;
  final bool requiresDoctorReview;
}

class ClinicalSnapshotEngine {
  const ClinicalSnapshotEngine({
    this.temporal = const TemporalEngine(),
    this.contradictions = const ContradictionEngine(),
    this.missingness = const MissingnessEngine(),
    this.uncertainty = const UncertaintyEngine(),
  });

  final TemporalEngine temporal;
  final ContradictionEngine contradictions;
  final MissingnessEngine missingness;
  final UncertaintyEngine uncertainty;

  ClinicalSnapshot build({
    required DoctorPatient patient,
    required Iterable<HealthEvent> events,
    required DateTime now,
    Iterable<String> expectedEventTypes = const <String>[],
    Iterable<String> openLoops = const <String>[],
  }) {
    final patientEvents =
        events.where((event) => event.subjectId == patient.id).toList()
          ..sort((a, b) {
            final time = a.temporal.observedAt.compareTo(b.temporal.observedAt);
            return time != 0 ? time : a.id.compareTo(b.id);
          });

    final sections = <SnapshotSectionKind, List<SnapshotItem>>{
      for (final kind in SnapshotSectionKind.values) kind: <SnapshotItem>[],
    };

    final conflicts = contradictions.detect(patientEvents);
    for (final conflict in conflicts) {
      sections[SnapshotSectionKind.conflicts]!.add(
        SnapshotItem(
          id: 'conflict-${conflict.left.id}-${conflict.right.id}',
          title: 'Conflicting evidence',
          detail: conflict.reason,
          evidenceIds: <String>[conflict.left.id, conflict.right.id]..sort(),
          priority: 100,
        ),
      );
    }

    final byType = <String, List<HealthEvent>>{};
    for (final event in patientEvents) {
      byType.putIfAbsent(event.eventType, () => <HealthEvent>[]).add(event);
    }

    for (final expectedType in expectedEventTypes.toSet().toList()..sort()) {
      final matching = byType[expectedType] ?? const <HealthEvent>[];
      if (matching.isEmpty) {
        sections[SnapshotSectionKind.missing]!.add(
          SnapshotItem(
            id: 'missing-$expectedType',
            title: 'Missing $expectedType',
            detail: 'No evidence is available for the expected data type.',
            evidenceIds: const <String>[],
            priority: 70,
          ),
        );
      }
    }

    for (final entry in byType.entries) {
      final values = entry.value;
      final latest = values.last;
      final assessment = uncertainty.assess(event: latest, now: now);
      if (!assessment.isKnownOnly) {
        sections[SnapshotSectionKind.uncertain]!.add(
          SnapshotItem(
            id: 'uncertain-${latest.id}',
            title: 'Uncertain ${entry.key}',
            detail: assessment.states.map((state) => state.name).join(', '),
            evidenceIds: <String>[latest.id],
            priority: 80,
          ),
        );
      }

      if (values.length >= 2) {
        final previous = values[values.length - 2];
        if (previous.value != null && latest.value != null) {
          final previousSummary = _singleEventBaseline(previous);
          final currentSummary = _singleEventBaseline(latest);
          final change = temporal.detectChange(
            previousSummary,
            currentSummary,
            policy: const ChangeDetectionPolicy(
              minimumAbsoluteChange: 0.000001,
              minimumRelativeChange: 0,
            ),
          );
          if (change.meaningful) {
            sections[SnapshotSectionKind.whatChanged]!.add(
              SnapshotItem(
                id: 'change-${previous.id}-${latest.id}',
                title: '${entry.key} ${change.comparison.direction.name}',
                detail:
                    'Δ ${change.comparison.absoluteChange.toStringAsFixed(2)}',
                evidenceIds: <String>[previous.id, latest.id],
                priority: 60,
              ),
            );
          }
        }
      }

      final unknownLike = missingness.isUnknownLike(latest);
      if (!unknownLike &&
          (latest.isClinicalSource ||
              latest.confidence == ConfidenceClass.high)) {
        sections[SnapshotSectionKind.whatMatters]!.add(
          SnapshotItem(
            id: 'matter-${latest.id}',
            title: entry.key,
            detail:
                latest.value?.toString() ?? latest.dataState?.name ?? 'present',
            evidenceIds: <String>[latest.id],
            priority: latest.isClinicalSource ? 90 : 50,
          ),
        );
      }
    }

    for (var i = 0; i < openLoops.length; i++) {
      final text = openLoops.elementAt(i);
      sections[SnapshotSectionKind.openLoops]!.add(
        SnapshotItem(
          id: 'open-loop-$i',
          title: text,
          detail: 'Requires clinician follow-up.',
          evidenceIds: const <String>[],
          priority: 65,
        ),
      );
    }

    for (final items in sections.values) {
      items.sort((a, b) {
        final priority = b.priority.compareTo(a.priority);
        return priority != 0 ? priority : a.id.compareTo(b.id);
      });
    }

    return ClinicalSnapshot(
      patientId: patient.id,
      generatedAt: now.toUtc(),
      sections: sections,
    );
  }

  BaselineSummary _singleEventBaseline(HealthEvent event) => BaselineSummary(
        subjectId: event.subjectId,
        eventType: event.eventType,
        count: 1,
        mean: event.value!.toDouble(),
        median: event.value!.toDouble(),
        minimum: event.value!.toDouble(),
        maximum: event.value!.toDouble(),
        standardDeviation: 0,
        windowStart: event.temporal.observedAt,
        windowEnd:
            event.temporal.observedAt.add(const Duration(microseconds: 1)),
      );
}
