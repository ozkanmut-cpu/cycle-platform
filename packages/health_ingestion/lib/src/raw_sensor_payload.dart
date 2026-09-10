import 'health_ingestion.dart';

class RawSensorPayload {
  const RawSensorPayload({
    required this.sourcePlatform,
    required this.sourceRecordId,
    required this.capturedAt,
    required this.bytes,
    this.contentType,
    this.metadata = const <String, Object?>{},
  });

  final HealthSourcePlatform sourcePlatform;
  final String sourceRecordId;
  final DateTime capturedAt;
  final List<int> bytes;
  final String? contentType;
  final Map<String, Object?> metadata;

  String get storageId => 'raw:${sourcePlatform.name}:$sourceRecordId';
}

abstract interface class RawSensorPayloadSink {
  Future<void> write(RawSensorPayload payload);
}
