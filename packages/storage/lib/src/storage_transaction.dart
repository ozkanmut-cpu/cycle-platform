abstract interface class StorageTransaction {
  Future<T> run<T>(Future<T> Function() action);
}
