import 'package:cycle_clinical_copilot/cycle_clinical_copilot.dart';
import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:test/test.dart';

void main() {
  final patient = Provenance(
    sourceKind: SourceKind.patient,
    sourceId: 'patient-entry',
  );
  final algorithm = Provenance(
    sourceKind: SourceKind.algorithm,
    sourceId: 'pattern-engine-v1',
  );
  final now = DateTime.utc(2026, 9, 14, 10);

  LearnedFactCandidate candidate({
    required String id,
    String patientId = 'p1',
    String key = 'preferred_check_in_time',
    String? value = 'morning',
    DataState state = DataState.yes,
    LearnedFactOrigin origin = LearnedFactOrigin.explicit,
    ConfidenceClass confidence = ConfidenceClass.high,
    Provenance? provenance,
    List<String> evidenceIds = const [],
    DateTime? learnedAt,
    DateTime? expiresAt,
  }) =>
      LearnedFactCandidate(
        id: id,
        patientId: patientId,
        key: key,
        value: value,
        state: state,
        origin: origin,
        confidence: confidence,
        provenance: provenance ?? patient,
        evidenceIds: evidenceIds,
        learnedAt: learnedAt ?? now,
        expiresAt: expiresAt,
      );

  test('explicit fact remains patient scoped and provenance linked', () {
    final profile = const LearnedAboutMeReconciler().reconcile(
      candidates: [candidate(id: 'a')],
      asOf: now,
    );
    final fact = profile.facts.single;
    expect(profile.patientId, 'p1');
    expect(fact.value, 'morning');
    expect(fact.lifecycle, LearnedFactLifecycle.active);
    expect(fact.provenances.single.sourceId, 'patient-entry');
  });

  test('derived facts require evidence', () {
    expect(
      () => candidate(
        id: 'd1',
        origin: LearnedFactOrigin.derived,
        provenance: algorithm,
      ),
      throwsA(isA<LearnedAboutMeValidationException>()),
    );
  });

  test('equivalent duplicates reconcile deterministically and merge evidence',
      () {
    final a = candidate(
      id: 'a',
      origin: LearnedFactOrigin.derived,
      provenance: algorithm,
      confidence: ConfidenceClass.medium,
      evidenceIds: ['e2'],
      learnedAt: now.subtract(const Duration(days: 2)),
    );
    final b = candidate(
      id: 'b',
      origin: LearnedFactOrigin.derived,
      provenance: algorithm,
      confidence: ConfidenceClass.high,
      evidenceIds: ['e1'],
      learnedAt: now.subtract(const Duration(days: 1)),
    );
    final reconciler = const LearnedAboutMeReconciler();
    final one = reconciler.reconcile(candidates: [a, b], asOf: now);
    final two = reconciler.reconcile(candidates: [b, a], asOf: now);
    expect(one.facts.single.evidenceIds, ['e1', 'e2']);
    expect(one.facts.single.value, two.facts.single.value);
    expect(one.facts.single.id, two.facts.single.id);
    expect(one.facts.single.confidence, ConfidenceClass.medium);
  });

  test('conflicting known values suppress a resolved value', () {
    final profile = const LearnedAboutMeReconciler().reconcile(
      candidates: [
        candidate(id: 'a', value: 'morning'),
        candidate(
          id: 'b',
          value: 'evening',
          learnedAt: now.add(const Duration(minutes: 1)),
        ),
      ],
      asOf: now.add(const Duration(minutes: 2)),
    );
    final fact = profile.facts.single;
    expect(fact.lifecycle, LearnedFactLifecycle.conflicted);
    expect(fact.value, isNull);
    expect(fact.state, DataState.unknown);
    expect(fact.confidence, ConfidenceClass.unknown);
  });

  test('unknown and not recorded never become false or zero', () {
    final profile = const LearnedAboutMeReconciler().reconcile(
      candidates: [
        candidate(
          id: 'u',
          key: 'exercise_preference',
          value: null,
          state: DataState.notRecorded,
          confidence: ConfidenceClass.unknown,
        ),
      ],
      asOf: now,
    );
    expect(profile.facts.single.state, DataState.notRecorded);
    expect(profile.facts.single.value, isNull);
  });

  test('stale and expired lifecycle preserve provenance', () {
    final reconciler = const LearnedAboutMeReconciler();
    final stale = reconciler.reconcile(
      candidates: [
        candidate(
          id: 'old',
          learnedAt: now.subtract(const Duration(days: 100)),
        ),
      ],
      asOf: now,
    );
    final expired = reconciler.reconcile(
      candidates: [
        candidate(
          id: 'expired',
          learnedAt: now.subtract(const Duration(days: 10)),
          expiresAt: now.subtract(const Duration(days: 1)),
        ),
      ],
      asOf: now,
    );
    expect(stale.facts.single.lifecycle, LearnedFactLifecycle.stale);
    expect(expired.facts.single.lifecycle, LearnedFactLifecycle.expired);
    expect(expired.facts.single.provenances, isNotEmpty);
  });

  test('mixed patients fail deterministically', () {
    expect(
      () => const LearnedAboutMeReconciler().reconcile(
        candidates: [
          candidate(id: 'a'),
          candidate(id: 'b', patientId: 'p2'),
        ],
        asOf: now,
      ),
      throwsA(isA<LearnedAboutMeValidationException>()),
    );
  });

  test('context projection passes only explicitly allowlisted learned keys',
      () {
    final profile = const LearnedAboutMeReconciler().reconcile(
      candidates: [
        candidate(id: 'a'),
        candidate(id: 'b', key: 'communication_style', value: 'concise'),
      ],
      asOf: now,
    );
    final result = const LearnedAboutMeContextProjector().project(
      profile: profile,
      policy: AiContextPolicy(allowedKeys: {'communication_style'}),
    );
    expect(result.validation.passed, isFalse);
    expect(result.allowedContext.keys, ['communication_style']);
    expect(result.blockedKeys, ['preferred_check_in_time']);
  });
}
