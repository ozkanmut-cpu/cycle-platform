import 'package:cycle_backup/cycle_backup.dart';
import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:test/test.dart';

void main() {
  test('builder encrypts payloads with dedicated backup key', () async {
    final backupKey = List<int>.generate(32, (index) => index + 1);
    final cipher = AesGcmAuthenticatedCipher(
      keyResolver: (keyEnvelopeId) async {
        expect(keyEnvelopeId, 'backup-key-v1');
        return backupKey;
      },
    );
    final builder = CycleVaultBuilder(
      cipher: cipher,
      backupKeyEnvelopeId: 'backup-key-v1',
    );

    final bytes = await builder.build(
      snapshotId: 'snapshot-1',
      createdAt: DateTime.utc(2026, 9, 9, 16),
      schemaVersion: 1,
      recordCount: 2,
      attachmentCount: 1,
      rawSensorEntryCount: 0,
      payloads: const <CycleVaultPayload>[
        CycleVaultPayload(
          name: 'database.snapshot',
          kind: 'database',
          bytes: <int>[1, 2, 3, 4],
        ),
      ],
    );

    final document = const CycleVaultCodec().decodeAndVerify(bytes);
    final entry = document.entries.single;
    expect(entry.envelope.ciphertext, isNot(<int>[1, 2, 3, 4]));
    expect(entry.envelope.keyEnvelopeId, 'backup-key-v1');

    final plaintext = await cipher.decrypt(entry.envelope);
    expect(plaintext, <int>[1, 2, 3, 4]);
  });
}
