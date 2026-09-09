class CiphertextEnvelope {
  const CiphertextEnvelope({
    required this.algorithm,
    required this.keyEnvelopeId,
    required this.nonce,
    required this.ciphertext,
    required this.authenticationTag,
    this.associatedData,
  });

  final String algorithm;
  final String keyEnvelopeId;
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> authenticationTag;
  final List<int>? associatedData;
}

abstract interface class AuthenticatedCipher {
  Future<CiphertextEnvelope> encrypt({
    required List<int> plaintext,
    required String keyEnvelopeId,
    List<int>? associatedData,
  });

  Future<List<int>> decrypt(CiphertextEnvelope envelope);
}
