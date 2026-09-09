import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:test/test.dart';

void main() {
  test('wraps and unwraps a 256-bit backup key', () async {
    final wrappingKey = List<int>.generate(32, (index) => index + 10);
    final backupKey = List<int>.generate(32, (index) => 255 - index);
    final cipher = AesGcmAuthenticatedCipher(
      keyResolver: (keyEnvelopeId) async {
        expect(keyEnvelopeId, 'recovery-wrap-v1');
        return wrappingKey;
      },
    );
    final service = BackupKeyEnvelopeService(cipher);

    final envelope = await service.wrap(
      backupKey: backupKey,
      wrappingKeyEnvelopeId: 'recovery-wrap-v1',
      wrappingMethod: 'recovery-passphrase',
      kdf: 'argon2id',
      kdfSalt: List<int>.filled(16, 7),
      kdfParameters: const <String, Object?>{
        'memoryKiB': 65536,
        'iterations': 3,
        'parallelism': 1,
      },
    );

    final restored = await service.unwrap(envelope);

    expect(restored, backupKey);
    expect(envelope.version, 1);
    expect(envelope.wrappingMethod, 'recovery-passphrase');
    expect(envelope.kdf, 'argon2id');
  });

  test('rejects non-256-bit backup keys', () async {
    final cipher = AesGcmAuthenticatedCipher(
      keyResolver: (_) async => List<int>.filled(32, 1),
    );
    final service = BackupKeyEnvelopeService(cipher);

    expect(
      () => service.wrap(
        backupKey: List<int>.filled(16, 1),
        wrappingKeyEnvelopeId: 'recovery-wrap-v1',
        wrappingMethod: 'recovery-passphrase',
      ),
      throwsArgumentError,
    );
  });
}
