import 'key_purpose.dart';
import 'secure_key_store.dart';

class CryptographicEraseResult {
  const CryptographicEraseResult({
    required this.deletedKeyIds,
    required this.completedAt,
  });

  final List<String> deletedKeyIds;
  final DateTime completedAt;
}

class CryptographicEraseService {
  const CryptographicEraseService(this._keyStore);

  final SecureKeyStore _keyStore;

  Future<CryptographicEraseResult> erasePurposes(
    Iterable<KeyPurpose> purposes,
  ) async {
    final deleted = <String>[];
    for (final purpose in purposes) {
      final keyId = purpose.name;
      await _keyStore.delete(keyId);
      deleted.add(keyId);
    }
    return CryptographicEraseResult(
      deletedKeyIds: List.unmodifiable(deleted),
      completedAt: DateTime.now().toUtc(),
    );
  }
}
