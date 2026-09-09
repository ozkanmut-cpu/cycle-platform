enum RecoveryState {
  idle,
  validating,
  readyToRestore,
  restoring,
  verifying,
  completed,
  failed,
}

class RecoverySnapshot {
  const RecoverySnapshot({
    required this.id,
    required this.createdAt,
    required this.schemaVersion,
    required this.recordCount,
    required this.attachmentCount,
    required this.integrityHash,
  });

  final String id;
  final DateTime createdAt;
  final int schemaVersion;
  final int recordCount;
  final int attachmentCount;
  final String integrityHash;
}

class RecoveryValidationResult {
  const RecoveryValidationResult({
    required this.snapshot,
    required this.integrityValid,
    required this.keyRecoverable,
    required this.schemaSupported,
    this.reason,
  });

  final RecoverySnapshot snapshot;
  final bool integrityValid;
  final bool keyRecoverable;
  final bool schemaSupported;
  final String? reason;

  bool get canRestore => integrityValid && keyRecoverable && schemaSupported;
}

abstract interface class RecoveryLifecycle {
  RecoveryState get state;

  Future<RecoveryValidationResult> validate(RecoverySnapshot snapshot);

  Future<void> restore(RecoverySnapshot snapshot);

  Future<void> verifyRestoredState(RecoverySnapshot snapshot);

  Future<void> reset();
}
