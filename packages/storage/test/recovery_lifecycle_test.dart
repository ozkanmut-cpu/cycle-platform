import 'package:cycle_storage/cycle_storage.dart';
import 'package:test/test.dart';

void main() {
  final snapshot = RecoverySnapshot(
    id: 'backup-1',
    createdAt: DateTime.utc(2026, 9, 9, 16),
    schemaVersion: 1,
    recordCount: 120,
    attachmentCount: 4,
    integrityHash: 'sha256:example',
  );

  test('restore requires integrity, key recovery and schema support', () {
    final valid = RecoveryValidationResult(
      snapshot: snapshot,
      integrityValid: true,
      keyRecoverable: true,
      schemaSupported: true,
    );

    expect(valid.canRestore, isTrue);

    final invalidIntegrity = RecoveryValidationResult(
      snapshot: snapshot,
      integrityValid: false,
      keyRecoverable: true,
      schemaSupported: true,
    );
    final missingKey = RecoveryValidationResult(
      snapshot: snapshot,
      integrityValid: true,
      keyRecoverable: false,
      schemaSupported: true,
    );
    final unsupportedSchema = RecoveryValidationResult(
      snapshot: snapshot,
      integrityValid: true,
      keyRecoverable: true,
      schemaSupported: false,
    );

    expect(invalidIntegrity.canRestore, isFalse);
    expect(missingKey.canRestore, isFalse);
    expect(unsupportedSchema.canRestore, isFalse);
  });
}
