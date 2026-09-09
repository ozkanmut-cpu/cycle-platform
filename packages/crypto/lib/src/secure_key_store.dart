import 'key_envelope.dart';
import 'key_purpose.dart';

abstract interface class SecureKeyStore {
  Future<KeyEnvelope> createKey(KeyPurpose purpose);

  Future<KeyEnvelope?> getActiveKey(KeyPurpose purpose);

  Future<KeyEnvelope> rotateKey(KeyPurpose purpose);

  Future<void> revokeKey(String envelopeId);

  Future<void> destroyAllKeys();
}
