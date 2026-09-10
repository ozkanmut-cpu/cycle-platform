import 'dart:convert';
import 'dart:io';

import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_intelligence/cycle_intelligence.dart';
import 'package:test/test.dart';

void main() {
  final fixture = _loadFixture();
  final now = DateTime.parse(fixture['now']! as String).toUtc();

  group('BaselineEngine', () {
    test('calculates deterministic subject-scoped personal baseline', () {
      final events = (fixture['baselineEvents']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(_eventFromFixture)
          .toList();
      final expected = fixture['expectedBaseline']! as Map<String, Object?>;

      final baseline = const BaselineEngine().calculatePersonal(
        events: events,
        subjectId: 'subject-1',
        eventType: 'vitals.heart_rate',
        from: now.subtract(const Duration(days: 7)),
        to: now,
      );

      expect(baseline, isNotNull);
      expect(baseline!.subjectId, 'subject-1');
      expect(baseline.count, expected['count']);
      expect(baseline.mean, expected['mean']);
      expect(baseline.median, expected['median']);
      expect(baseline.minimum, expected['minimum']);
      expect(baseline.maximum, expected['maximum']);
      expect(
        baseline.standardDeviation,
        closeTo((expected['standardDeviation']! as num).toDouble(), 0.000001),
      );
    });

    test('returns null when the requested window has no values', () {
      final baseline = const BaselineEngine().calculatePersonal(
        events: const [],
        subjectId: 'subject-1',
        eventType: 'vitals.heart_rate',
        from: now.subtract(const Duration(days: 7)),
        to: now,
      );
      expect(baseline, isNull);
    });

    test('rejects inverted or empty windows deterministically', () {
      expect(
        () => const BaselineEngine().calculatePersonal(
          events: const [],
          subjectId: 'subject-1',
          eventType: 'vitals.heart_rate',
          from: now,
          to: now,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TemporalEngine', () {
    test('exposes direction and relative change', () {
      final previous = _baseline(mean: 50);
      final current = _baseline(mean: 60);
      final result = const TemporalEngine().compare(previous, current);

      expect(result.absoluteChange, 10);
      expect(result.relativeChange, closeTo(0.2, 0.000001));
      expect(result.direction, ChangeDirection.increased);
    });

    test('runs deterministic change-detection hooks', () {
      final signals = <ChangeSignal>[];
      final signal = const TemporalEngine().detectChange(
        _baseline(mean: 50),
        _baseline(mean: 60),
        policy: ChangeDetectionPolicy(
          minimumAbsoluteChange: 5,
          minimumRelativeChange: 0.1,
        ),
        hooks: [signals.add],
      );

      expect(signal.meaningful, isTrue);
      expect(signals, hasLength(1));
      expect(identical(signals.single, signal), isTrue);
    });

    test('rejects comparisons across subjects', () {
      expect(
        () => const TemporalEngine().compare(
          _baseline(mean: 50, subjectId: 'subject-1'),
          _baseline(mean: 60, subjectId: 'subject-2'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('missingness and uncertainty', () {
    test('Unknown is distinct from explicit No and payload-less events', () {
      const engine = MissingnessEngine();
      expect(
        engine.classify(_event('no', dataState: DataState.no)),
        MissingnessKind.explicitNo,
      );
      expect(
        engine.classify(_event('unknown', dataState: DataState.unknown)),
        MissingnessKind.unknown,
      );
      expect(engine.classify(_event('payload-less')), MissingnessKind.unknown);
      expect(engine.classify(null), MissingnessKind.absent);
      expect(engine.isUnknownLike(null), isTrue);
      expect(
        engine
            .isExplicitlyAnswered(_event('answered', dataState: DataState.no)),
        isTrue,
      );
    });

    test('combines every uncertainty state without losing missing context', () {
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

    test('null evidence can still be incomplete and conflicting', () {
      final result = const UncertaintyEngine().assess(
        event: null,
        now: now,
        incompleteHistory: true,
        conflicting: true,
      );
      expect(
        result.states,
        {
          IntelligenceState.unknown,
          IntelligenceState.incomplete,
          IntelligenceState.conflicting,
        },
      );
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

  group('ContradictionEngine', () {
    test('detects same-moment numeric disagreement', () {
      final at = now.subtract(const Duration(hours: 1));
      final conflicts = const ContradictionEngine(numericTolerance: 2).detect([
        _event('left', value: 70, observedAt: at),
        _event('right', value: 80, observedAt: at),
      ]);

      expect(conflicts, hasLength(1));
      expect(conflicts.single.left.id, 'left');
      expect(conflicts.single.right.id, 'right');
    });

    test('detects explicit yes-no contradiction but not unknown-no', () {
      final at = now.subtract(const Duration(hours: 1));
      const engine = ContradictionEngine();
      expect(
        engine.contradicts(
          _event('yes', dataState: DataState.yes, observedAt: at),
          _event('no', dataState: DataState.no, observedAt: at),
        ),
        isTrue,
      );
      expect(
        engine.contradicts(
          _event('unknown', dataState: DataState.unknown, observedAt: at),
          _event('no-2', dataState: DataState.no, observedAt: at),
        ),
        isFalse,
      );
    });
  });

  group('Information Value and Zero-Log Day', () {
    test('asks only when expected value clears burden', () {
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
      expect(highValue.score, inInclusiveRange(0, 1));
    });

    test('ZeroLogDay suppresses needless prompts and asks for high-value gaps',
        () {
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
        engine
            .decide(
              userLoggedToday: true,
              passiveDataPresent: false,
              informationValue: high,
            )
            .shouldPrompt,
        isFalse,
      );
      expect(
        engine
            .decide(
              userLoggedToday: false,
              passiveDataPresent: true,
              informationValue: low,
            )
            .shouldPrompt,
        isFalse,
      );
      expect(
        engine
            .decide(
              userLoggedToday: false,
              passiveDataPresent: false,
              informationValue: high,
            )
            .shouldPrompt,
        isTrue,
      );
    });
  });

  group('HealthDataTimeMachine', () {
    test('queries observation-time windows with subject filters', () {
      final old = _event(
        'old',
        observedAt: now.subtract(const Duration(days: 10)),
      );
      final recent = _event(
        'recent',
        observedAt: now.subtract(const Duration(days: 2)),
      );
      final other = _event(
        'other',
        subjectId: 'subject-2',
        observedAt: now.subtract(const Duration(days: 1)),
      );
      final result = const HealthDataTimeMachine().between(
        [old, recent, other],
        from: now.subtract(const Duration(days: 7)),
        to: now,
        subjectId: 'subject-1',
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

    test('snapshotAsOf excludes observations from the future', () {
      final futureObservation = _event(
        'future',
        observedAt: now.add(const Duration(days: 1)),
        knownAt: now.subtract(const Duration(days: 1)),
      );
      final current = _event(
        'current',
        observedAt: now.subtract(const Duration(days: 1)),
        knownAt: now.subtract(const Duration(hours: 1)),
      );

      final result = const HealthDataTimeMachine().snapshotAsOf(
        [futureObservation, current],
        asOf: now,
      );

      expect(result.map((event) => event.id), ['current']);
    });

    test('ordering is deterministic for equal observation timestamps', () {
      final at = now.subtract(const Duration(days: 1));
      final result = const HealthDataTimeMachine().between(
        [
          _event('z', observedAt: at),
          _event('a', observedAt: at),
        ],
        from: now.subtract(const Duration(days: 2)),
        to: now,
      );
      expect(result.map((event) => event.id), ['a', 'z']);
    });
  });
}

Map<String, Object?> _loadFixture() {
  final raw = File('test/fixtures/intelligence_cases.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, Object?>;
}

HealthEvent _eventFromFixture(Map<String, Object?> row) => _event(
      row['id']! as String,
      subjectId: row['subjectId']! as String,
      value: row['value']! as num,
      observedAt: DateTime.parse(row['observedAt']! as String).toUtc(),
    );

BaselineSummary _baseline({
  required double mean,
  String subjectId = 'subject-1',
}) =>
    BaselineSummary(
      subjectId: subjectId,
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
  String subjectId = 'subject-1',
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
    subjectId: subjectId,
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
