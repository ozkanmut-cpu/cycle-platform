import 'key_purpose.dart';

class KeyEnvelope {
  const KeyEnvelope({
    required this.id,
    required this.purpose,
    required this.version,
    required this.wrappedKey,
    required this.createdAt,
    this.rotatedFromEnvelopeId,
    this.revokedAt,
  });

  final String id;
  final KeyPurpose purpose;
  final int version;
  final List<int> wrappedKey;
  final DateTime createdAt;
  final String? rotatedFromEnvelopeId;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;
}
