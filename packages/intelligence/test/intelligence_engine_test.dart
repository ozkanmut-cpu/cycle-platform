import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_intelligence/cycle_intelligence.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 10, 8);

  group('BaselineEngine', () {
    test('calculates deterministic personal baseline statistics', () {
      final events = [
        _event('a', value: 60, observedAt: now.subtract(const Duration(days: 3))),
        _event('b', value: 70, observedAt: now.subtract(const Duration(days: 2))),
        _event('c', value: 80, observedAt: now.subtract(const Duration(days: 1))),
      ];

      final baseline = const BaselineEngine().calculate(
        events: events,
        eventType: 'vitals.heart_rate',
        from: now.subtract(const Duration(days: 7)),
        to: now,
      );

      expect(baseline, isNotNull);
      expect(baseline!.count, 3);
      expect(baseline.mean, 70);
      expect(baseline.median, 70);
      expect(baseline.minimum, 60);
      expect(baseline.maximum, 80);
      expect(baseline.standardDeviation, closeTo(8.1649658, 0.000001));
    });

    test('returns null when the requested window has no values', () {
      final baseline = const BaselineEngine().calculate(
        events: const [],
        eventType: 'vitals.heart_rate',
        from: now.subtract(const Duration(days: 7)),
        to: now,
      );
      expect(baseline, isNull);
    });
  });

  test('TemporalEngine exposes direction and relative change', () {
    final previous = _baseline(mean: 50);
    final current = _baseline(mean: 60);
    final result = const TemporalEngine().compare(previous, current);

    expect(result.absoluteChange, 10);
    expect(result.relativeChange, closeTo(0.2, 0.000001));
    expect(result.direction, ChangeDirection.increased);
  });

  group('missingness and uncertainty', () {
    test('Unknown is distinct from explicit No', () {
      const engine = MissingnessEngine();
      expect(
        engine.classify(_event('no', dataState: DataState.no)),
        MissingnessKind.explicitNo,
      );
      expect(
        engine.classify(_event('unknown', dataState: DataState.unknown)),
        MissingnessKind.unknown,
      );
      expect(engine.classify(null), MissingnessKind.absent);
      expect(engine.isUnknownLike(null), isTrue);
    });

    test('combines estimated stale incomplete low-confidence and conflict', () {
      final event = _event(
        'uncertain',
        value: 70,
        observedAt: now.subtract(const Duration(days: 60)),
        verificationStatus: VerificationStatus.estimated,
        confidence: ConfidenceClass.low,
      );
      final result = const UncertaintyEngine().assess(
        event: event,
        now: now,
        incompleteHistory: true,
        conflicting: true,
      );

      expect(
        result.states,
        containsAll({
          IntelligenceState.estimated,
          IntelligenceState.stale,
          IntelligenceState.incomplete,
          IntelligenceState.lowConfidence,
          IntelligenceState.conflicting,
        }),
      );
      expect(result.states, isNot(contains(IntelligenceState.known)));
    });

    test('clean current evidence is known', () {
      final result = const UncertaintyEngine().assess(
        event: _event('known', value: 70, observedAt: now),
        now: now,
      );
      expect(result.states, {IntelligenceState.known});
      expect(result.isKnownOnly, isTrue);
    });
  });

  test('ContradictionEngine detects same-moment numeric disagreement', () {
    final at = now.subtract(const Duration(hours: 1));
    final conflicts = const ContradictionEngine(numericTolerance: 2).detect([
      _event('left', value: 70, observedAt: at),
      _event('right', value: 80, observedAt: at),
    ]);

    expect(conflicts, hasLength(1));
    expect(conflicts.single.left.id, 'left');
    expect(conflicts.single.right.id, 'right');
  });

  test('InformationValueEngine asks only when expected value clears burden', () {
    const engine = InformationValueEngine(askThreshold: 0.6);
    const uncertain = UncertaintyAssessment({
      IntelligenceState.unknown,
      IntelligenceState.incomplete,
      IntelligenceState.lowConfidence,
    });

    final highValue = engine.evaluate(
      uncertainty: uncertain,
      decisionImpact: 1,
      userBurden: 0.1,
    );
    final lowValue = engine.evaluate(
      uncertainty: const UncertaintyAssessment({IntelligenceState.known}),
      decisionImpact: 0.2,
      userBurden: 0.8,
    );

    expect(highValue.shouldAsk, isTrue);
    expect(lowValue.shouldAsk, isFalse);
  });

  test('ZeroLogDay avoids needless prompts and prompts for high value gaps', () {
    const engine = ZeroLogDayEngine();
    const high = InformationValueResult(
      score: 0.9,
      shouldAsk: true,
      reasons: [],
    );
    const low = InformationValueResult(
      score: 0.2,
      shouldAsk: false,
      reasons: [],
    );

    expect(
      engine.decide(
        userLoggedToday: true,
        passiveDataPresent: false,
        informationValue: high,
      ).shouldPrompt,
      isFalse,
    );
    expect(
      engine.decide(
        userLoggedToday: false,
        passiveDataPresent: true,
        informationValue: low,
      ).shouldPrompt,
      isFalse,
    );
    expect(
      engine.decide(
        userLoggedToday: false,
        passiveDataPresent: false,
        informationValue: high,
      ).shouldPrompt,
      isTrue,
    );
  });

  group('HealthDataTimeMachine', () {
    test('queries observation-time windows deterministically', () {
      final old = _event(
        'old',
        observedAt: now.subtract(const Duration(days: 10)),
      );
      final recent = _event(
        'recent',
        observedAt: now.subtract(const Duration(days: 2)),
      );
      final result = const HealthDataTimeMachine().between(
        [old, recent],
        from: now.subtract(const Duration(days: 7)),
        to: now,
      );
      expect(result.map((event) => event.id), ['recent']);
    });

    test('knownAsOf excludes facts learned later', () {
      final knownEarly = _event(
        'early',
        observedAt: now.subtract(const Duration(days: 20)),
        knownAt: now.subtract(const Duration(days: 5)),
      );
      final knownLate = _event(
        'late',
        observedAt: now.subtract(const Duration(days: 20)),
        knownAt: now.add(const Duration(days: 1)),
      );
      final result = const HealthDataTimeMachine().knownAsOf(
        [knownLate, knownEarly],
        asOf: now,
      );
      expect(result.map((event) => event.id), ['early']);
    });
  });
}

BaselineSummary _baseline({required double mean}) => BaselineSummary(
      eventType: 'vitals.heart_rate',
      count: 2,
      mean: mean,
      median: mean,
      minimum: mean,
      maximum: mean,
      standardDeviation: 0,
      windowStart: DateTime.utc(2026, 9, 1),
      windowEnd: DateTime.utc(2026, 9, 2),
    );

HealthEvent _event(
  String id, {
  num? value,
  DataState? dataState,
  DateTime? observedAt,
  DateTime? knownAt,
  VerificationStatus verificationStatus = VerificationStatus.deviceMeasured,
  ConfidenceClass confidence = ConfidenceClass.high,
}) {
  final observed = observedAt ?? DateTime.utc(2026, 9, 10, 8);
  return HealthEvent(
    id: id,
    subjectId: 'subject-1',
    eventType: 'vitals.heart_rate',
    value: value,
    dataState: dataState,
    temporal: TemporalMetadata(
      observedAt: observed,
      recordedAt: observed,
      knownAt: knownAt,
    ),
    provenance: const Provenance(sourceKind: SourceKind.device),
    verificationStatus: verificationStatus,
    confidence: confidence,
    privacyClass: 'health',
    schemaVersion: 1,
  );
}
