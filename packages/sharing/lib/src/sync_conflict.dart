class SyncVersionedValue<T> {
  const SyncVersionedValue({
    required this.value,
    required this.revision,
    required this.modifiedAt,
    required this.deviceId,
  });

  final T value;
  final int revision;
  final DateTime modifiedAt;
  final String deviceId;
}

class SyncConflictResolver {
  const SyncConflictResolver();

  SyncVersionedValue<T> resolve<T>(
    SyncVersionedValue<T> left,
    SyncVersionedValue<T> right,
  ) {
    final revision = left.revision.compareTo(right.revision);
    if (revision != 0) return revision > 0 ? left : right;

    final modified =
        left.modifiedAt.toUtc().compareTo(right.modifiedAt.toUtc());
    if (modified != 0) return modified > 0 ? left : right;

    return left.deviceId.compareTo(right.deviceId) <= 0 ? left : right;
  }
}
