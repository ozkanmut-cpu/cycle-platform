import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';

class NormalizedHealthEventMapper {
  const NormalizedHealthEventMapper();

  String eventIdFor({
    required HealthSourcePlatform sourcePlatform,
    required String sourceRecordId,
  }) => 'import:${sourcePlatform.name}:$sourceRecordId';

  HealthEvent toHealthEvent({
    required String subjectId,
    required NormalizedHealthRecord record,
    required DateTime importedAt,
  }) {
    final normalizedValue = record.normalizedValue;
    final now = importedAt.toUtc();

    return HealthEvent(
      id: eventIdFor(
        sourcePlatform: record.source.sourcePlatform,
        sourceRecordId: record.source.sourceRecordId,
      ),
      subjectId: subjectId,
      eventType: record.mapping.canonicalCode,
      value: normalizedValue is num ? normalizedValue : null,
      unit: record.normalizedUnit,
      dataState: DataState.yes,
      temporal: TemporalMetadata(
        observedAt: record.source.observedAt.toUtc(),
        recordedAt: now,
        importedAt: now,
        knownAt: now,
      ),
      provenance: record.provenance,
      verificationStatus: VerificationStatus.deviceMeasured,
      confidence: ConfidenceClass.high,
      privacyClass: record.mapping.category == HealthDataCategory.reproductive
          ? 'reproductive'
          : 'health',
      schemaVersion: 1,
    );
  }
}
