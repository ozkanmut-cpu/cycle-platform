import 'cycle_vault.dart';

class RecoveryDrillResult {
  const RecoveryDrillResult({
    required this.integrityValid,
    required this.schemaSupported,
    required this.keyRecoverable,
    required this.recordCount,
    required this.attachmentCount,
    required this.rawSensorEntryCount,
    required this.completedAt,
    this.reason,
  });

  final bool integrityValid;
  final bool schemaSupported;
  final bool keyRecoverable;
  final int recordCount;
  final int attachmentCount;
  final int rawSensorEntryCount;
  final DateTime completedAt;
  final String? reason;

  bool get passed => integrityValid && schemaSupported && keyRecoverable;
}

class RecoveryDrill {
  const RecoveryDrill({
    this.codec = const CycleVaultCodec(),
    required this.maxSupportedSchemaVersion,
    required this.keyRecoverabilityCheck,
  });

  final CycleVaultCodec codec;
  final int maxSupportedSchemaVersion;
  final Future<bool> Function(CycleVaultDocument document)
      keyRecoverabilityCheck;

  Future<RecoveryDrillResult> run(List<int> bytes) async {
    try {
      final document = codec.decodeAndVerify(bytes);
      final schemaSupported =
          document.manifest.schemaVersion <= maxSupportedSchemaVersion;
      if (!schemaSupported) {
        return RecoveryDrillResult(
          integrityValid: true,
          schemaSupported: false,
          keyRecoverable: false,
          recordCount: document.manifest.recordCount,
          attachmentCount: document.manifest.attachmentCount,
          rawSensorEntryCount: document.manifest.rawSensorEntryCount,
          completedAt: DateTime.now().toUtc(),
          reason: 'Backup schema is newer than this app supports.',
        );
      }

      final keyRecoverable = await keyRecoverabilityCheck(document);
      return RecoveryDrillResult(
        integrityValid: true,
        schemaSupported: true,
        keyRecoverable: keyRecoverable,
        recordCount: document.manifest.recordCount,
        attachmentCount: document.manifest.attachmentCount,
        rawSensorEntryCount: document.manifest.rawSensorEntryCount,
        completedAt: DateTime.now().toUtc(),
        reason:
            keyRecoverable ? null : 'Backup encryption key is not recoverable.',
      );
    } on FormatException catch (error) {
      return RecoveryDrillResult(
        integrityValid: false,
        schemaSupported: false,
        keyRecoverable: false,
        recordCount: 0,
        attachmentCount: 0,
        rawSensorEntryCount: 0,
        completedAt: DateTime.now().toUtc(),
        reason: error.message,
      );
    }
  }
}
