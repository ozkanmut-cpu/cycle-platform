import 'dart:io';

import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:cycle_storage_file_vault/cycle_storage_file_vault.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late AesGcmAuthenticatedCipher cipher;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cycle-vault-test-');
    final key = List<int>.generate(32, (index) => index + 1);
    cipher = AesGcmAuthenticatedCipher(
      keyResolver: (_) async => key,
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('attachment vault round-trips encrypted blob', () async {
    final vault = EncryptedAttachmentVault(
      directory: directory,
      cipher: cipher,
      keyEnvelopeId: 'attachment-key-v1',
    );
    final createdAt = DateTime.utc(2026, 9, 9, 16);
    final blob = VaultBlob(
      id: 'ultrasound-report-1',
      bytes: <int>[1, 2, 3, 4],
      createdAt: createdAt,
      contentType: 'application/pdf',
      originalName: 'report.pdf',
      metadata: const <String, Object?>{'kind': 'ultrasound'},
    );

    await vault.write(blob);
    final restored = await vault.read(blob.id);

    expect(restored, isNotNull);
    expect(restored!.bytes, blob.bytes);
    expect(restored.createdAt, createdAt);
    expect(restored.originalName, 'report.pdf');
    expect(restored.metadata['kind'], 'ultrasound');

    final files =
        await directory.list().where((entry) => entry is File).toList();
    expect(files, hasLength(1));
    expect(files.single.path, isNot(contains(blob.id)));
    expect(
      await (files.single as File).readAsString(),
      isNot(contains('report.pdf')),
    );
  });

  test('attachment and raw sensor vault namespaces are isolated', () async {
    final attachmentDirectory = Directory('${directory.path}/attachments');
    final sensorDirectory = Directory('${directory.path}/sensors');
    final attachmentVault = EncryptedAttachmentVault(
      directory: attachmentDirectory,
      cipher: cipher,
      keyEnvelopeId: 'attachment-key-v1',
    );
    final sensorVault = EncryptedRawSensorVault(
      directory: sensorDirectory,
      cipher: cipher,
      keyEnvelopeId: 'sensor-key-v1',
    );
    final blob = VaultBlob(
      id: 'same-id',
      bytes: <int>[7, 8, 9],
      createdAt: DateTime.utc(2026, 9, 9, 16),
    );

    await attachmentVault.write(blob);
    await sensorVault.write(blob);

    final attachmentFile = (await attachmentDirectory
            .list()
            .where((entry) => entry is File)
            .toList())
        .single;
    final sensorFile =
        (await sensorDirectory.list().where((entry) => entry is File).toList())
            .single;

    expect(
      attachmentFile.path.split('/').last,
      isNot(sensorFile.path.split('/').last),
    );
  });

  test('delete removes encrypted blob', () async {
    final vault = EncryptedRawSensorVault(
      directory: directory,
      cipher: cipher,
      keyEnvelopeId: 'sensor-key-v1',
    );
    final blob = VaultBlob(
      id: 'hrv-raw-1',
      bytes: <int>[11, 22, 33],
      createdAt: DateTime.utc(2026, 9, 9, 16),
    );

    await vault.write(blob);
    expect(await vault.contains(blob.id), isTrue);

    await vault.delete(blob.id);
    expect(await vault.contains(blob.id), isFalse);
    expect(await vault.read(blob.id), isNull);
  });
}
