import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_intelligence/cycle_intelligence.dart';
import 'package:test/test.dart';

void main() {
  const engine = MissingnessEngine();

  test('missingness keeps absent unknown not-recorded and explicit no distinct',
      () {
    expect(engine.classify(null), MissingnessKind.absent);
    expect(engine.classify(_event(DataState.unknown)), MissingnessKind.unknown);
    expect(
      engine.classify(_event(DataState.notRecorded)),
      MissingnessKind.notRecorded,
    );
    expect(engine.classify(_event(DataState.no)), MissingnessKind.explicitNo);
    expect(
      engine.classify(_event(DataState.notApplicable)),
      MissingnessKind.notApplicable,
    );
    expect(engine.classify(_event(DataState.yes)), MissingnessKind.present);
  });

  test('unknown-like never includes explicit no', () {
    expect(engine.isUnknownLike(null), isTrue);
    expect(engine.isUnknownLike(_event(DataState.unknown)), isTrue);
    expect(engine.isUnknownLike(_event(DataState.notRecorded)), isTrue);
    expect(engine.isUnknownLike(_event(DataState.no)), isFalse);
  });
}

HealthEvent _event(DataState state) => HealthEvent(
      id: 'event-${state.name}',
      subjectId: 'subject-1',
      eventType: 'symptom.example',
      dataState: state,
      temporal: TemporalMetadata(
        observedAt: DateTime.utc(2026, 9, 10),
        recordedAt: DateTime.utc(2026, 9, 10),
      ),
      provenance: const Provenance(sourceKind: SourceKind.patient),
      verificationStatus: VerificationStatus.selfReported,
      confidence: ConfidenceClass.high,
      privacyClass: 'sensitive',
      schemaVersion: 1,
    );
