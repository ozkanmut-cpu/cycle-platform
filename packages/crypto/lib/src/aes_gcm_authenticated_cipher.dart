import 'package:cryptography/cryptography.dart';

import 'authenticated_cipher.dart';

typedef KeyMaterialResolver = Future<List<int>> Function(String keyEnvelopeId);

class AesGcmAuthenticatedCipher implements AuthenticatedCipher {
  AesGcmAuthenticatedCipher({
    required KeyMaterialResolver keyResolver,
    AesGcm? algorithm,
  }) : _keyResolver = keyResolver,
       _algorithm = algorithm ?? AesGcm.with256bits();

  final KeyMaterialResolver _keyResolver;
  final AesGcm _algorithm;

  @override
  Future<CiphertextEnvelope> encrypt({
    required List<int> plaintext,
    required String keyEnvelopeId,
    List<int>? associatedData,
  }) async {
    final keyBytes = await _keyResolver(keyEnvelopeId);
    _validateKey(keyBytes);

    final secretBox = await _algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(keyBytes),
      aad: associatedData ?? const <int>[],
    );

    return CiphertextEnvelope(
      algorithm: 'AES-256-GCM',
      keyEnvelopeId: keyEnvelopeId,
      nonce: List<int>.unmodifiable(secretBox.nonce),
      ciphertext: List<int>.unmodifiable(secretBox.cipherText),
      authenticationTag: List<int>.unmodifiable(secretBox.mac.bytes),
      associatedData: associatedData == null
          ? null
          : List<int>.unmodifiable(associatedData),
    );
  }

  @override
  Future<List<int>> decrypt(CiphertextEnvelope envelope) async {
    if (envelope.algorithm != 'AES-256-GCM') {
      throw ArgumentError.value(
        envelope.algorithm,
        'envelope.algorithm',
        'Unsupported cipher algorithm.',
      );
    }

    final keyBytes = await _keyResolver(envelope.keyEnvelopeId);
    _validateKey(keyBytes);

    final secretBox = SecretBox(
      envelope.ciphertext,
      nonce: envelope.nonce,
      mac: Mac(envelope.authenticationTag),
    );

    return _algorithm.decrypt(
      secretBox,
      secretKey: SecretKey(keyBytes),
      aad: envelope.associatedData ?? const <int>[],
    );
  }

  void _validateKey(List<int> keyBytes) {
    if (keyBytes.length != 32) {
      throw ArgumentError.value(
        keyBytes.length,
        'keyBytes.length',
        'AES-256-GCM requires a 32-byte key.',
      );
    }
  }
}
