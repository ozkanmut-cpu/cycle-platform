import 'key_purpose.dart';
import 'secure_key_store.dart';

class CryptographicEraseResult {
  const CryptographicEraseResult({
    required this.revokedEnvelopeIds,
    required this.completedAt,
  });

  final List<String> revokedEnvelopeIds;
  final DateTime completedAt;
}

class CryptographicEraseService {
  const CryptographicEraseService(this._keyStore);

  final SecureKeyStore _keyStore;

  Future<CryptographicEraseResult> erasePurposes(
    Iterable<KeyPurpose> purposes,
  ) async {
    final revoked = <String>[];
    for (final purpose in purposes) {
      final envelope = await _keyStore.getActiveKey(purpose);
      if (envelope == null) continue;
      await _keyStore.revokeKey(envelope.id);
      revoked.add(envelope.id);
    }
    return CryptographicEraseResult(
      revokedEnvelopeIds: List.unmodifiable(revoked),
      completedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> eraseEntireVault() => _keyStore.destroyAllKeys();
}
