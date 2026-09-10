import 'package:cycle_clinical_copilot/cycle_clinical_copilot.dart';
import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 10, 9);
  const patient = DoctorPatient(id: 'p1', displayName: 'Patient One');

  test('Clinical Snapshot exposes all six workflow sections', () {
    final previous = _event('hr-old', 70, now.subtract(const Duration(days: 2)));
    final latest = _event('hr-new', 85, now.subtract(const Duration(days: 1)));
    final conflicting = _event(
      'hr-conflict',
      95,
      now.subtract(const Duration(days: 1)),
    );

    final snapshot = const ClinicalSnapshotEngine().build(
      patient: patient,
      events: <HealthEvent>[previous, latest, conflicting],
      now: now,
      expectedEventTypes: <String>['vitals.heart_rate', 'labs.hgb'],
      openLoops: <String>['Repeat CBC'],
    );

    expect(snapshot.patientId, 'p1');
    expect(snapshot.sections.keys.toSet(), SnapshotSectionKind.values.toSet());
    expect(snapshot.section(SnapshotSectionKind.whatChanged), isNotEmpty);
    expect(snapshot.section(SnapshotSectionKind.whatMatters), isNotEmpty);
    expect(snapshot.section(SnapshotSectionKind.missing), hasLength(1));
    expect(snapshot.section(SnapshotSectionKind.conflicts), isNotEmpty);
    expect(snapshot.section(SnapshotSectionKind.openLoops), hasLength(1));
  });

  test('Clinical Compression produces evidence-linked deterministic graph', () {
    final result = const ClinicalCompressionEngine().compress(
      patientId: 'p1',
      items: <SnapshotItem>[
        SnapshotItem(
          id: 'b',
          title: 'Second',
          detail: 'detail',
          evidenceIds: <String>['e2'],
          priority: 1,
        ),
        SnapshotItem(
          id: 'a',
          title: 'First',
          detail: 'detail',
          evidenceIds: <String>['e1'],
          priority: 2,
        ),
      ],
    );

    expect(result.summary, 'First · Second');
    expect(result.evidenceIds, <String>['e1', 'e2']);
    expect(result.graph.evidenceFor('summary-a').single.sourceId, 'e1');
  });

  test('natural-language search routes only to structured query primitives', () {
    const router = SafeRecordQueryRouter();
    expect(
      router
          .route(patientId: 'p1', naturalLanguage: 'show conflicts', now: now)
          .kind,
      StructuredQueryKind.conflicts,
    );
    final sevenDays = router.route(
      patientId: 'p1',
      naturalLanguage: 'son 7 gün',
      now: now,
    );
    expect(sevenDays.kind, StructuredQueryKind.between);
    expect(sevenDays.from, now.subtract(const Duration(days: 7)));
    expect(sevenDays.to, now);
  });

  test('reasoning workspace is patient-scoped and chronologically ordered', () {
    final workspace = ClinicalReasoningWorkspace();
    workspace.add(
      ReasoningNote(
        id: 'late',
        patientId: 'p1',
        authorId: 'doctor-1',
        text: 'late',
        evidenceIds: const <String>[],
        createdAt: now,
      ),
    );
    workspace.add(
      ReasoningNote(
        id: 'early',
        patientId: 'p1',
        authorId: 'doctor-1',
        text: 'early',
        evidenceIds: const <String>[],
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
    );
    expect(workspace.forPatient('p1').map((note) => note.id), ['early', 'late']);
  });

  test('Doctor Review Gate prevents autonomous clinical writes', () {
    const gate = DoctorReviewGate();
    const proposal = ProposedClinicalWrite(
      id: 'proposal-1',
      patientId: 'p1',
      actionType: 'medication-change',
      payload: <String, Object?>{'drug': 'example'},
      evidenceIds: <String>['e1'],
    );

    expect(gate.canCommit(proposal, null), isFalse);
    expect(
      () => gate.approve(
        proposal,
        DoctorReviewRecord(
          proposalId: 'proposal-1',
          reviewerId: 'doctor-1',
          decision: ReviewDecision.rejected,
          reviewedAt: now,
        ),
      ),
      throwsStateError,
    );

    final approved = gate.approve(
      proposal,
      DoctorReviewRecord(
        proposalId: 'proposal-1',
        reviewerId: 'doctor-1',
        decision: ReviewDecision.approved,
        reviewedAt: now,
      ),
    );
    expect(approved.disposition, ClinicalWriteDisposition.approved);
  });

  test('trial, question and AI audit hooks preserve evidence and review state', () {
    final trial = TreatmentTrialHook(
      id: 'trial-1',
      patientId: 'p1',
      hypothesis: 'Intervention changes symptom burden',
      startAt: now,
      endAt: now.add(const Duration(days: 14)),
      outcomeEventTypes: const <String>['symptom.score'],
    );
    const question = ClinicalQuestionProtocolHook(
      id: 'q-1',
      patientId: 'p1',
      question: 'Is the trend persistent?',
      requiredEvidenceTypes: <String>['vitals.heart_rate'],
    );
    final audit = AiOutputAuditRecord(
      id: 'ai-1',
      patientId: 'p1',
      modelId: 'clinical-copilot-test',
      promptPurpose: 'snapshot-summary',
      output: 'Evidence-linked summary',
      evidenceIds: <String>['e1', 'e2'],
      generatedAt: now,
      requiresDoctorReview: true,
    );

    expect(trial.outcomeEventTypes, contains('symptom.score'));
    expect(question.requiredEvidenceTypes, contains('vitals.heart_rate'));
    expect(audit.evidenceIds, <String>['e1', 'e2']);
    expect(audit.requiresDoctorReview, isTrue);
  });
}

HealthEvent _event(String id, num value, DateTime observedAt) => HealthEvent(
      id: id,
      subjectId: 'p1',
      eventType: 'vitals.heart_rate',
      value: value,
      temporal: TemporalMetadata(
        observedAt: observedAt,
        recordedAt: observedAt,
      ),
      provenance: const Provenance(sourceKind: SourceKind.device),
      verificationStatus: VerificationStatus.deviceMeasured,
      confidence: ConfidenceClass.high,
      privacyClass: 'health',
      schemaVersion: 1,
    );
