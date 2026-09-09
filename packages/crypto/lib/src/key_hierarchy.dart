import 'key_purpose.dart';

class KeyDescriptor {
  const KeyDescriptor({
    required this.id,
    required this.purpose,
    required this.version,
    required this.createdAt,
    this.parentKeyId,
    this.revokedAt,
  });

  final String id;
  final KeyPurpose purpose;
  final int version;
  final DateTime createdAt;
  final String? parentKeyId;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;
}

abstract interface class KeyHierarchy {
  Future<KeyDescriptor> ensureMasterKey();
  Future<KeyDescriptor> ensurePurposeKey(KeyPurpose purpose);
  Future<KeyDescriptor> rotatePurposeKey(KeyPurpose purpose);
  Future<void> revokePurposeKey(KeyPurpose purpose);
  Future<List<KeyDescriptor>> listActiveKeys();
}
