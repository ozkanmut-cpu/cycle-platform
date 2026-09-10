import 'package:cycle_clinical_copilot/cycle_clinical_copilot.dart';
import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:test/test.dart';

void main() {
  const matcher = DoctorResultMatcher();
  final start = DateTime.utc(2026, 9, 1);
  final end = DateTime.utc(2026, 9, 10);

  HealthEvent event(
    String id,
    String patientId,
    String eventType,
    DateTime observedAt,
  ) {
    return HealthEvent(
      id: id,
      subjectId: patientId,
      eventType: eventType,
      temporal: TemporalMetadata(
        observedAt: observedAt,
        recordedAt: observedAt,
        knownAt: observedAt,
      ),
      provenance: const Provenance(sourceKind: SourceKind.clinicalSystem),
      verificationStatus: VerificationStatus.clinicalSource,
      confidence: ConfidenceClass.high,
      privacyClass: 'clinical',
      schemaVersion: 1,
    );
  }

  test('matches treatment results by patient, type and inclusive window', () {
    final trial = TreatmentTrialHook(
      id: 'trial-1',
      patientId: 'p1',
      hypothesis: 'tracked response',
      startAt: start,
      endAt: end,
      outcomeEventTypes: const ['lab.a', 'symptom.score'],
    );

    final result = matcher.matchTreatmentTrial(
      trial: trial,
      events: [
        event('other-patient', 'p2', 'lab.a', start),
        event('at-end', 'p1', 'lab.a', end),
        event('symptom', 'p1', 'symptom.score', start),
      ],
    );

    expect(result.hasMissing, isFalse);
    expect(result.results.map((item) => item.requirement), [
      'lab.a',
      'symptom.score',
    ]);
    expect(result.results.first.status, ResultMatchStatus.matched);
    expect(result.results.first.eventIds, ['at-end']);
    expect(result.results.last.eventIds, ['symptom']);
  });

  test('distinguishes missing from out-of-window trial evidence', () {
    final trial = TreatmentTrialHook(
      id: 'trial-2',
      patientId: 'p1',
      hypothesis: 'tracked response',
      startAt: start,
      endAt: end,
      outcomeEventTypes: const ['lab.a', 'lab.missing'],
    );

    final result = matcher.matchTreatmentTrial(
      trial: trial,
      events: [
        event('too-old', 'p1', 'lab.a', start.subtract(const Duration(days: 1)))
      ],
    );

    expect(result.results[0].status, ResultMatchStatus.outOfWindow);
    expect(result.results[0].eventIds, ['too-old']);
    expect(result.results[1].status, ResultMatchStatus.missing);
    expect(result.results[1].eventIds, isEmpty);
  });

  test('clinical question matching is patient-isolated and reports missing',
      () {
    final protocol = ClinicalQuestionProtocolHook(
      id: 'question-1',
      patientId: 'p1',
      question: 'Are required results available?',
      requiredEvidenceTypes: const ['lab.a', 'lab.b'],
    );

    final result = matcher.matchClinicalQuestion(
      protocol: protocol,
      events: [
        event('wrong-patient', 'p2', 'lab.b', start),
        event('right-patient', 'p1', 'lab.a', end),
      ],
    );

    expect(result.results[0].requirement, 'lab.a');
    expect(result.results[0].status, ResultMatchStatus.matched);
    expect(result.results[0].eventIds, ['right-patient']);
    expect(result.results[1].requirement, 'lab.b');
    expect(result.results[1].status, ResultMatchStatus.missing);
  });

  test('ordering is deterministic regardless of input order', () {
    final trial = TreatmentTrialHook(
      id: 'trial-3',
      patientId: 'p1',
      hypothesis: 'tracked response',
      startAt: start,
      endAt: end,
      outcomeEventTypes: const ['z.result', 'a.result', 'z.result'],
    );
    final first =
        event('b', 'p1', 'a.result', start.add(const Duration(days: 2)));
    final second =
        event('a', 'p1', 'a.result', start.add(const Duration(days: 1)));

    final left = matcher.matchTreatmentTrial(
      trial: trial,
      events: [first, second],
    );
    final right = matcher.matchTreatmentTrial(
      trial: trial,
      events: [second, first],
    );

    expect(
        left.results.map((item) => item.requirement), ['a.result', 'z.result']);
    expect(left.results.first.eventIds, ['a', 'b']);
    expect(right.results.first.eventIds, left.results.first.eventIds);
  });

  test('rejects invalid treatment trial chronology', () {
    final trial = TreatmentTrialHook(
      id: 'trial-invalid',
      patientId: 'p1',
      hypothesis: 'invalid',
      startAt: end,
      endAt: start,
      outcomeEventTypes: const ['lab.a'],
    );

    expect(
      () => matcher.matchTreatmentTrial(trial: trial, events: const []),
      throwsArgumentError,
    );
  });
}
