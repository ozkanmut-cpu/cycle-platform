import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_patient/month_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HealthEvent _event({
  required String id,
  required String type,
  required DateTime observedAt,
}) {
  return HealthEvent(
    id: id,
    subjectId: 'local-owner',
    eventType: type,
    dataState: DataState.yes,
    temporal: TemporalMetadata(
      observedAt: observedAt,
      recordedAt: observedAt,
      knownAt: observedAt,
    ),
    provenance: const Provenance(sourceKind: SourceKind.patient),
    verificationStatus: VerificationStatus.selfReported,
    confidence: ConfidenceClass.high,
    privacyClass: 'reproductive',
    schemaVersion: 1,
  );
}

void main() {
  testWidgets('calendar shows event marker and selected-day cycle day', (
    tester,
  ) async {
    final events = <HealthEvent>[
      _event(
        id: 'period',
        type: 'menstruation.period_start',
        observedAt: DateTime(2026, 9, 1, 8),
      ),
      _event(
        id: 'cramps',
        type: 'symptom.cramps',
        observedAt: DateTime(2026, 9, 3, 12),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthCalendar(
            events: events,
            initialMonth: DateTime(2026, 9),
          ),
        ),
      ),
    );

    expect(find.text('2026-09'), findsOneWidget);
    await tester.tap(find.text('3'));
    await tester.pump();

    expect(find.text('Cycle day 3'), findsOneWidget);
    expect(find.text('1 logged event(s)'), findsOneWidget);
  });
}
