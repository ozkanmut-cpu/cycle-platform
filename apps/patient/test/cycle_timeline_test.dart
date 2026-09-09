import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_patient/cycle_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

HealthEvent event(String id, String type, DateTime observedAt) {
  return HealthEvent(
    id: id,
    subjectId: 'local-owner',
    eventType: type,
    dataState: DataState.yes,
    provenance: const Provenance(sourceKind: SourceKind.patient),
    verificationStatus: VerificationStatus.selfReported,
    confidence: ConfidenceClass.high,
    privacyClass: 'reproductive',
    temporal: TemporalMetadata(
      observedAt: observedAt,
      recordedAt: observedAt,
      knownAt: observedAt,
    ),
    schemaVersion: 1,
  );
}

void main() {
  test('cycle day starts at one on latest period start', () {
    final timeline = CycleTimeline(<HealthEvent>[
      event('p1', 'menstruation.period_start', DateTime.utc(2026, 9, 1, 8)),
      event('p0', 'menstruation.period_start', DateTime.utc(2026, 8, 3, 8)),
    ]);

    expect(timeline.cycleDayFor(DateTime.utc(2026, 9, 1)), 1);
    expect(timeline.cycleDayFor(DateTime.utc(2026, 9, 9)), 9);
  });

  test('cycle day is unknown before any period start', () {
    final timeline = CycleTimeline(<HealthEvent>[
      event('s1', 'symptom.cramps', DateTime.utc(2026, 9, 9, 8)),
    ]);

    expect(timeline.cycleDayFor(DateTime.utc(2026, 9, 9)), isNull);
  });

  test('events are grouped by local calendar day', () {
    final timeline = CycleTimeline(<HealthEvent>[
      event('a', 'symptom.cramps', DateTime.utc(2026, 9, 9, 7)),
      event('b', 'symptom.headache', DateTime.utc(2026, 9, 9, 9)),
    ]);

    final grouped = timeline.groupedByDay();
    expect(grouped.values.single.length, 2);
  });
}
