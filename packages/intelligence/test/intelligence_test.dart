import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_intelligence/cycle_intelligence.dart';
import 'package:test/test.dart';

void main() {
  group('Baseline and temporal engines', () {
    test('calculate deterministic personal baseline and direction', () {
      const baseline = BaselineEngine();
      const temporal = TemporalEngine();
      final events = [
        _event('a', 60, DateTime.utc(2026, 1, 1)),
        _event('b', 70, DateTime.utc(2026, 1, 2)),
        _event('c', 80, DateTime.utc(2026, 2, 1)),
        _event('d', 90, DateTime.utc(2026, 2, 2)),
      ];

      final previous = baseline.calculate(
        events: events,
        eventType: 'vitals.heart_rate',
        from: DateTime.utc(2026, 1, 1),
        to: DateTime.utc(2026, 2, 1),
      )!;
      final current = baseline.calculate(
        events: events,
        eventType: 'vitals.heart_rate',
        from: DateTime.utc(2026, 2, 1),
        to: DateTime.utc(2026, 3, 1),
      )!;
      final comparison = temporal.compare(previous, current);

      expect(previous.mean, 65);
      expect(previous.median, 65);
      expect(previous.standardDeviation, 5);
      expect(current.mean, 85);
      expect(comparison.absoluteChange, 20);
      expect(comparison.relativeChange, closeTo(20 / 65, 1e-12));
      expect(comparison.direction, ChangeDirection.increased);
    });
  });

  group('Uncertainty and contradiction', () {
    test('preserves unknown instead of turning missing into No', () {
      const engine = UncertaintyEngine();
      final assessment = engine.assess(
        event: null,
        now: DateTime.utc(2026, 9, 10),
      );
      expect(assessment.states, {IntelligenceState.unknown});
    });

    test('can represent estimated stale incomplete low-confidence conflict',
        () {
      const engine = UncertaintyEngine(staleAfter: Duration(days: 7));
      final assessment = engine.assess(
        event: _event(
          'estimated',
          42,
          DateTime.utc(2026, 8, 1),
          verificationStatus: VerificationStatus.estimated,
          confidence: ConfidenceClass.low,
        ),
        now: DateTime.utc(2026, 9, 10),
        incompleteHistory: true,
        conflicting: true,
      );
      expect(
        assessment.states,
        containsAll({
          IntelligenceState.estimated,
          IntelligenceState.stale,
          IntelligenceState.incomplete,
          IntelligenceState.lowConfidence,
          IntelligenceState.conflicting,
        }),
      );
    });

    test('known remains explicit when no uncertainty applies', () {
      const engine = UncertaintyEngine();
      final assessment = engine.assess(
        event: _event('known', 72, DateTime.utc(2026, 9, 9)),
        now: DateTime.utc(2026, 9, 10),
      );
      expect(assessment.states, {IntelligenceState.known});
      expect(assessment.isKnownOnly, isTrue);
    });

    test('detects same-time numeric contradictions', () {
      const engine = ContradictionEngine(numericTolerance: 1);
      final when = DateTime.utc(2026, 9, 10, 10);
      final conflicts = engine.detect([
        _event('left', 70, when),
        _event('right', 75, when),
      ]);
      expect(conflicts, hasLength(1));
      expect(conflicts.single.reason, 'Conflicting numeric values.');
    });
  });

  group('Information value and zero-log day', () {
    test('asks only when information value clears threshold', () {
      const information = InformationValueEngine(askThreshold: 0.6);
      const zeroLog = ZeroLogDayEngine();
      const uncertainty = UncertaintyAssessment({
        IntelligenceState.unknown,
        IntelligenceState.incomplete,
      });

      final result = information.evaluate(
        uncertainty: uncertainty,
        decisionImpact: 1,
        userBurden: 0.1,
      );
      final decision = zeroLog.decide(
        userLoggedToday: false,
        passiveDataPresent: false,
        informationValue: result,
      );
      expect(result.shouldAsk, isTrue);
      expect(decision.shouldPrompt, isTrue);
    });

    test('zero-log day stays silent when asking adds little value', () {
      const information = InformationValueEngine();
      const zeroLog = ZeroLogDayEngine();
      const uncertainty = UncertaintyAssessment({IntelligenceState.known});
      final result = information.evaluate(
        uncertainty: uncertainty,
        decisionImpact: 0.2,
        userBurden: 0.8,
      );
      final decision = zeroLog.decide(
        userLoggedToday: false,
        passiveDataPresent: true,
        informationValue: result,
      );
      expect(decision.shouldPrompt, isFalse);
    });
  });

  group('Health Data Time Machine', () {
    test('queries point-in-time history deterministically', () {
      const machine = HealthDataTimeMachine();
      final events = [
        _event('jan', 60, DateTime.utc(2026, 1, 1)),
        _event('feb', 70, DateTime.utc(2026, 2, 1)),
        _event('mar', 80, DateTime.utc(2026, 3, 1)),
      ];
      final slice = machine.between(
        events,
        from: DateTime.utc(2026, 1, 15),
        to: DateTime.utc(2026, 3, 1),
        eventType: 'vitals.heart_rate',
      );
      final latest = machine.latestBefore(
        events,
        at: DateTime.utc(2026, 2, 15),
        eventType: 'vitals.heart_rate',
      );
      expect(slice.map((event) => event.id), ['feb']);
      expect(latest?.id, 'feb');
    });
  });
}

HealthEvent _event(
  String id,
  num value,
  DateTime observedAt, {
  VerificationStatus verificationStatus = VerificationStatus.deviceMeasured,
  ConfidenceClass confidence = ConfidenceClass.high,
}) {
  return HealthEvent(
    id: id,
    subjectId: 'subject-1',
    eventType: 'vitals.heart_rate',
    value: value,
    unit: 'bpm',
    temporal: TemporalMetadata(observedAt: observedAt, recordedAt: observedAt),
    provenance: const Provenance(sourceKind: SourceKind.device),
    verificationStatus: verificationStatus,
    confidence: confidence,
    privacyClass: 'sensitive',
    schemaVersion: 1,
  );
}
