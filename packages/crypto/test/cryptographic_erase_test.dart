import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:test/test.dart';

void main() {
  test('erasePurposes revokes only requested active keys', () async {
    final store = _MemorySecureKeyStore();
    final database = await store.createKey(KeyPurpose.database);
    await store.createKey(KeyPurpose.attachment);
    final service = CryptographicEraseService(store);

    final result = await service.erasePurposes(<KeyPurpose>[
      KeyPurpose.database,
      KeyPurpose.notification,
    ]);

    expect(result.revokedEnvelopeIds, <String>[database.id]);
    expect(await store.getActiveKey(KeyPurpose.database), isNull);
    expect(await store.getActiveKey(KeyPurpose.attachment), isNotNull);
  });

  test('eraseEntireVault destroys every key', () async {
    final store = _MemorySecureKeyStore();
    await store.createKey(KeyPurpose.master);
    await store.createKey(KeyPurpose.backup);
    final service = CryptographicEraseService(store);

    await service.eraseEntireVault();

    for (final purpose in KeyPurpose.values) {
      expect(await store.getActiveKey(purpose), isNull);
    }
  });
}

class _MemorySecureKeyStore implements SecureKeyStore {
  final Map<KeyPurpose, KeyEnvelope> _active = <KeyPurpose, KeyEnvelope>{};
  int _sequence = 0;

  @override
  Future<KeyEnvelope> createKey(KeyPurpose purpose) async {
    final current = _active[purpose];
    if (current != null) return current;
    return _put(purpose, 1);
  }

  @override
  Future<KeyEnvelope?> getActiveKey(KeyPurpose purpose) async {
    return _active[purpose];
  }

  @override
  Future<KeyEnvelope> rotateKey(KeyPurpose purpose) async {
    final current = _active[purpose];
    return _put(purpose, (current?.version ?? 0) + 1);
  }

  @override
  Future<void> revokeKey(String envelopeId) async {
    final match = _active.entries.where(
      (entry) => entry.value.id == envelopeId,
    );
    if (match.isNotEmpty) {
      _active.remove(match.first.key);
    }
  }

  @override
  Future<void> destroyAllKeys() async {
    _active.clear();
  }

  KeyEnvelope _put(KeyPurpose purpose, int version) {
    _sequence += 1;
    final envelope = KeyEnvelope(
      id: '${purpose.name}-$_sequence',
      purpose: purpose,
      version: version,
      wrappedKey: List<int>.filled(32, _sequence),
      createdAt: DateTime.utc(2026, 9, 9, 16),
    );
    _active[purpose] = envelope;
    return envelope;
  }
}
