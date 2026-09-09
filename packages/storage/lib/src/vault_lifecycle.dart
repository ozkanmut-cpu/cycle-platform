enum VaultState { uninitialized, locked, unlocked, corrupted, erased }

abstract interface class VaultLifecycle {
  Future<VaultState> state();
  Future<void> initialize();
  Future<void> unlock();
  Future<void> lock();
  Future<void> verifyIntegrity();
  Future<void> erase();
}
