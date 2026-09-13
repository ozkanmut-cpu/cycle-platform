import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_fertility_domain/cycle_fertility_domain.dart';
import 'package:test/test.dart';

void main() {
  final source = DomainProvenance(
    sourceId: 'patient',
    recordedAt: DateTime.utc(2026, 9, 14, 8),
  );

  test('kick count includes only explicit movement observations', () {
    final session = KickCountSession(
      id: 'kick-1',
      pregnancyEpisodeId: 'preg-1',
      startedAt: DateTime.utc(2026, 9, 14, 8),
      endedAt: DateTime.utc(2026, 9, 14, 9),
      observations: [
        FetalMovementObservation(
          id: 'm2',
          observedAt: DateTime.utc(2026, 9, 14, 8, 20),
          state: DataState.yes,
          provenance: source,
        ),
        FetalMovementObservation(
          id: 'm1',
          observedAt: DateTime.utc(2026, 9, 14, 8, 10),
          state: DataState.unknown,
          provenance: source,
        ),
      ],
    );

    expect(session.explicitMovementCount, 1);
    expect(session.hasIncompleteData, isTrue);
    expect(session.observations.map((item) => item.id), ['m1', 'm2']);
  });

  test('missing movement data never becomes zero evidence', () {
    final session = KickCountSession(
      id: 'kick-2',
      pregnancyEpisodeId: 'preg-1',
      startedAt: DateTime.utc(2026, 9, 14, 8),
      observations: [
        FetalMovementObservation(
          id: 'm1',
          observedAt: DateTime.utc(2026, 9, 14, 8, 5),
          state: DataState.notRecorded,
          provenance: source,
        ),
      ],
    );

    expect(session.explicitMovementCount, 0);
    expect(session.hasIncompleteData, isTrue);
  });

  test('contraction timing derives duration and start intervals', () {
    final session = ContractionSession(
      id: 'c-session',
      pregnancyEpisodeId: 'preg-1',
      startedAt: DateTime.utc(2026, 9, 14, 8),
      observations: [
        ContractionObservation(
          id: 'c1',
          startedAt: DateTime.utc(2026, 9, 14, 8, 10),
          endedAt: DateTime.utc(2026, 9, 14, 8, 10, 45),
          state: DataState.yes,
          provenance: source,
        ),
        ContractionObservation(
          id: 'c2',
          startedAt: DateTime.utc(2026, 9, 14, 8, 16),
          endedAt: DateTime.utc(2026, 9, 14, 8, 17),
          state: DataState.yes,
          provenance: source,
        ),
      ],
    );

    final summary = session.summarize();
    expect(summary.timings[0].duration, const Duration(seconds: 45));
    expect(summary.timings[0].intervalFromPreviousStart, isNull);
    expect(
      summary.timings[1].intervalFromPreviousStart,
      const Duration(minutes: 6),
    );
    expect(summary.overlappingObservationIds, isEmpty);
  });

  test('unknown contraction remains incomplete and has no derived timing', () {
    final session = ContractionSession(
      id: 'c-session',
      pregnancyEpisodeId: 'preg-1',
      startedAt: DateTime.utc(2026, 9, 14, 8),
      observations: [
        ContractionObservation(
          id: 'c1',
          startedAt: DateTime.utc(2026, 9, 14, 8, 10),
          state: DataState.unknown,
          provenance: source,
        ),
      ],
    );

    final summary = session.summarize();
    expect(summary.hasIncompleteData, isTrue);
    expect(summary.timings.single.duration, isNull);
    expect(summary.timings.single.intervalFromPreviousStart, isNull);
  });

  test('overlapping explicit contractions are surfaced deterministically', () {
    final session = ContractionSession(
      id: 'c-session',
      pregnancyEpisodeId: 'preg-1',
      startedAt: DateTime.utc(2026, 9, 14, 8),
      observations: [
        ContractionObservation(
          id: 'b',
          startedAt: DateTime.utc(2026, 9, 14, 8, 10, 30),
          endedAt: DateTime.utc(2026, 9, 14, 8, 11),
          state: DataState.yes,
          provenance: source,
        ),
        ContractionObservation(
          id: 'a',
          startedAt: DateTime.utc(2026, 9, 14, 8, 10),
          endedAt: DateTime.utc(2026, 9, 14, 8, 10, 45),
          state: DataState.yes,
          provenance: source,
        ),
      ],
    );

    expect(session.summarize().overlappingObservationIds, {'a', 'b'});
  });

  test('duplicate normalized ids fail deterministically', () {
    expect(
      () => KickCountSession(
        id: 'kick',
        pregnancyEpisodeId: 'preg-1',
        startedAt: DateTime.utc(2026, 9, 14, 8),
        observations: [
          FetalMovementObservation(
            id: 'Move-1',
            observedAt: DateTime.utc(2026, 9, 14, 8, 5),
            state: DataState.yes,
            provenance: source,
          ),
          FetalMovementObservation(
            id: ' move-1 ',
            observedAt: DateTime.utc(2026, 9, 14, 8, 6),
            state: DataState.yes,
            provenance: source,
          ),
        ],
      ),
      throwsA(isA<PregnancyTrackingValidationException>()),
    );
  });

  test('invalid contraction chronology fails', () {
    expect(
      () => ContractionSession(
        id: 'c',
        pregnancyEpisodeId: 'preg-1',
        startedAt: DateTime.utc(2026, 9, 14, 8),
        observations: [
          ContractionObservation(
            id: 'c1',
            startedAt: DateTime.utc(2026, 9, 14, 8, 10),
            endedAt: DateTime.utc(2026, 9, 14, 8, 9),
            state: DataState.yes,
            provenance: source,
          ),
        ],
      ),
      throwsA(isA<PregnancyTrackingValidationException>()),
    );
  });

  test('tracking can be validated against pregnancy episode boundaries', () {
    final pregnancy = PregnancyEpisode(
      id: 'preg-1',
      startedAt: DateTime.utc(2026, 1, 1),
      endedAt: DateTime.utc(2026, 9, 10),
      dating: PregnancyDating(
        estimatedStartDate: DateTime.utc(2026, 1, 1),
        basis: 'reported',
        provenance: source,
      ),
    );

    expect(
      () => validateTrackingAgainstPregnancy(
        pregnancy: pregnancy,
        sessionStartedAt: DateTime.utc(2026, 9, 14),
      ),
      throwsA(isA<PregnancyTrackingValidationException>()),
    );
  });
}
