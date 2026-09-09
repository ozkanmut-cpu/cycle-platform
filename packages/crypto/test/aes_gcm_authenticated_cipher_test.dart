import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:test/test.dart';

void main() {
  final key = List<int>.generate(32, (index) => index + 1);
  final cipher = AesGcmAuthenticatedCipher(
    keyResolver: (keyEnvelopeId) async {
      expect(keyEnvelopeId, 'key-1');
      return key;
    },
  );

  test('round-trips plaintext with associated data', () async {
    final envelope = await cipher.encrypt(
      plaintext: <int>[1, 2, 3, 4, 5],
      keyEnvelopeId: 'key-1',
      associatedData: <int>[9, 8, 7],
    );

    final plaintext = await cipher.decrypt(envelope);

    expect(plaintext, <int>[1, 2, 3, 4, 5]);
    expect(envelope.algorithm, 'AES-256-GCM');
    expect(envelope.nonce, hasLength(12));
    expect(envelope.authenticationTag, hasLength(16));
  });

  test('tampering fails authentication', () async {
    final envelope = await cipher.encrypt(
      plaintext: <int>[10, 20, 30],
      keyEnvelopeId: 'key-1',
      associatedData: <int>[1, 1, 1],
    );

    final tampered = CiphertextEnvelope(
      algorithm: envelope.algorithm,
      keyEnvelopeId: envelope.keyEnvelopeId,
      nonce: envelope.nonce,
      ciphertext: <int>[envelope.ciphertext.first ^ 1, ...envelope.ciphertext.skip(1)],
      authenticationTag: envelope.authenticationTag,
      associatedData: envelope.associatedData,
    );

    expect(() => cipher.decrypt(tampered), throwsA(isA<Object>()));
  });
}
