class VaultRecord<T> {
  const VaultRecord({
    required this.id,
    required this.value,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final T value;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}
