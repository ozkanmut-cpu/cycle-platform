import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_storage_sqlcipher/cycle_storage_sqlcipher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not create a revision for the same imported observation', () {
    final existing = _event(
      value: 70,
      recordedAt: DateTime.utc(2026, 9, 10, 0),
    );
    final incoming = _event(
      value: 70,
      recordedAt: DateTime.utc(2026, 9, 10, 1),
    );

    final plan = ImportedHealthEventRevision.plan(
      existing: existing,
      incoming: incoming,
    );

    expect(plan, isNull);
  });

  test('preserves the previous value and links the replacement', () {
    final existing = _event(
      value: 70,
      recordedAt: DateTime.utc(2026, 9, 10, 0),
    );
    final incoming = _event(
      value: 71,
      recordedAt: DateTime.utc(2026, 9, 10, 1),
    );

    final plan = ImportedHealthEventRevision.plan(
      existing: existing,
      incoming: incoming,
    );

    expect(plan, isNotNull);
    expect(plan!.snapshot.value, 70);
    expect(
      plan.snapshot.id,
      'import:healthConnect:weight-1:revision:'
      '${existing.temporal.recordedAt.microsecondsSinceEpoch}',
    );
    expect(plan.current.id, existing.id);
    expect(plan.current.value, 71);
    expect(plan.current.supersedesEventId, plan.snapshot.id);
  });
}

HealthEvent _event({required num value, required DateTime recordedAt}) {
  final observedAt = DateTime.utc(2026, 9, 9, 23, 50);
  return HealthEvent(
    id: 'import:healthConnect:weight-1',
    subjectId: 'local-owner',
    eventType: 'body.weight',
    value: value,
    unit: 'kg',
    dataState: DataState.yes,
    temporal: TemporalMetadata(
      observedAt: observedAt,
      recordedAt: recordedAt,
      importedAt: recordedAt,
      knownAt: recordedAt,
    ),
    provenance: const Provenance(
      sourceKind: SourceKind.healthConnect,
      sourceName: 'Health Connect',
      sourceRecordId: 'weight-1',
      deviceName: 'Pixel',
    ),
    verificationStatus: VerificationStatus.deviceMeasured,
    confidence: ConfidenceClass.high,
    privacyClass: 'health',
    schemaVersion: 1,
  );
}
