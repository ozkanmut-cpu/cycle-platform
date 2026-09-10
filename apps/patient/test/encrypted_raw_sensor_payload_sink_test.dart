import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:cycle_patient/health/encrypted_raw_sensor_payload_sink.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps raw sensor payload into the encrypted raw sensor vault', () async {
    final vault = _FakeRawSensorVault();
    final sink = EncryptedRawSensorPayloadSink(vault);
    final capturedAt = DateTime.utc(2026, 9, 10, 0, 30);

    await sink.write(
      RawSensorPayload(
        sourcePlatform: HealthSourcePlatform.healthConnect,
        sourceRecordId: 'sensor-1',
        capturedAt: capturedAt,
        bytes: const <int>[1, 2, 3, 4],
        contentType: 'application/octet-stream',
        metadata: const <String, Object?>{'channel': 'spo2-waveform'},
      ),
    );

    final blob = vault.lastWritten;
    expect(blob, isNotNull);
    expect(blob!.id, 'raw:healthConnect:sensor-1');
    expect(blob.bytes, <int>[1, 2, 3, 4]);
    expect(blob.createdAt, capturedAt);
    expect(blob.contentType, 'application/octet-stream');
    expect(blob.metadata['sourcePlatform'], 'healthConnect');
    expect(blob.metadata['sourceRecordId'], 'sensor-1');
    expect(blob.metadata['channel'], 'spo2-waveform');
  });
}

class _FakeRawSensorVault implements RawSensorVault {
  VaultBlob? lastWritten;

  @override
  Future<bool> contains(String id) async => lastWritten?.id == id;

  @override
  Future<void> delete(String id) async {
    if (lastWritten?.id == id) lastWritten = null;
  }

  @override
  Future<VaultBlob?> read(String id) async =>
      lastWritten?.id == id ? lastWritten : null;

  @override
  Future<void> write(VaultBlob blob) async {
    lastWritten = blob;
  }
}
