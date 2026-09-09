class VaultBlob {
  const VaultBlob({
    required this.id,
    required this.bytes,
    required this.createdAt,
    this.contentType,
    this.originalName,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final List<int> bytes;
  final DateTime createdAt;
  final String? contentType;
  final String? originalName;
  final Map<String, Object?> metadata;
}

abstract interface class BinaryVault {
  Future<void> write(VaultBlob blob);
  Future<VaultBlob?> read(String id);
  Future<void> delete(String id);
  Future<bool> contains(String id);
}

abstract interface class AttachmentVault implements BinaryVault {}

abstract interface class RawSensorVault implements BinaryVault {}
