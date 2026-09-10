import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:cycle_storage/cycle_storage.dart';

class EncryptedRawSensorPayloadSink implements RawSensorPayloadSink {
  const EncryptedRawSensorPayloadSink(this.vault);

  final RawSensorVault vault;

  @override
  Future<void> write(RawSensorPayload payload) {
    return vault.write(
      VaultBlob(
        id: payload.storageId,
        bytes: List<int>.unmodifiable(payload.bytes),
        createdAt: payload.capturedAt.toUtc(),
        contentType: payload.contentType,
        metadata: <String, Object?>{
          'sourcePlatform': payload.sourcePlatform.name,
          'sourceRecordId': payload.sourceRecordId,
          'capturedAt': payload.capturedAt.toUtc().toIso8601String(),
          ...payload.metadata,
        },
      ),
    );
  }
}
