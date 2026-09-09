import 'package:cycle_backup/cycle_backup.dart';
import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:test/test.dart';

void main() {
  test('restorer decrypts verified payloads only', () async {
    final backupKey = List<int>.generate(32, (index) => 200 - index);
    final cipher = AesGcmAuthenticatedCipher(
      keyResolver: (_) async => backupKey,
    );
    final builder = CycleVaultBuilder(
      cipher: cipher,
      backupKeyEnvelopeId: 'backup-key-v1',
    );
    final bytes = await builder.build(
      snapshotId: 'snapshot-restore',
      createdAt: DateTime.utc(2026, 9, 9, 16),
      schemaVersion: 2,
      recordCount: 1,
      attachmentCount: 0,
      rawSensorEntryCount: 0,
      payloads: const <CycleVaultPayload>[
        CycleVaultPayload(
          name: 'database.snapshot',
          kind: 'database',
          bytes: <int>[42, 43, 44],
        ),
      ],
    );
    final restorer = CycleVaultRestorer(
      cipher: cipher,
      maxSupportedSchemaVersion: 2,
    );

    final restored = await restorer.restore(bytes);

    expect(restored.payloads.single.bytes, <int>[42, 43, 44]);
  });

  test('restorer refuses newer schemas before decrypting', () async {
    var decryptAttempted = false;
    final key = List<int>.filled(32, 7);
    final encryptCipher = AesGcmAuthenticatedCipher(
      keyResolver: (_) async => key,
    );
    final bytes = await CycleVaultBuilder(
      cipher: encryptCipher,
      backupKeyEnvelopeId: 'backup-key-v1',
    ).build(
      snapshotId: 'snapshot-newer',
      createdAt: DateTime.utc(2026, 9, 9, 16),
      schemaVersion: 99,
      recordCount: 1,
      attachmentCount: 0,
      rawSensorEntryCount: 0,
      payloads: const <CycleVaultPayload>[
        CycleVaultPayload(
            name: 'database.snapshot', kind: 'database', bytes: <int>[1]),
      ],
    );
    final decryptCipher = AesGcmAuthenticatedCipher(
      keyResolver: (_) async {
        decryptAttempted = true;
        return key;
      },
    );
    final restorer = CycleVaultRestorer(
      cipher: decryptCipher,
      maxSupportedSchemaVersion: 2,
    );

    await expectLater(restorer.restore(bytes), throwsStateError);
    expect(decryptAttempted, isFalse);
  });
}
