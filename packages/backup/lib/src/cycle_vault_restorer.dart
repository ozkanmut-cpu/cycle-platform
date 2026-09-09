import 'package:cycle_crypto/cycle_crypto.dart';

import 'cycle_vault.dart';
import 'cycle_vault_builder.dart';

class CycleVaultRestoreResult {
  const CycleVaultRestoreResult({
    required this.document,
    required this.payloads,
  });

  final CycleVaultDocument document;
  final List<CycleVaultPayload> payloads;
}

class CycleVaultRestorer {
  const CycleVaultRestorer({
    required this.cipher,
    required this.maxSupportedSchemaVersion,
    this.codec = const CycleVaultCodec(),
  });

  final AuthenticatedCipher cipher;
  final int maxSupportedSchemaVersion;
  final CycleVaultCodec codec;

  Future<CycleVaultRestoreResult> restore(List<int> bytes) async {
    final document = codec.decodeAndVerify(bytes);
    if (document.manifest.schemaVersion > maxSupportedSchemaVersion) {
      throw StateError('Backup schema is newer than this app supports.');
    }

    final payloads = <CycleVaultPayload>[];
    for (final entry in document.entries) {
      final plaintext = await cipher.decrypt(entry.envelope);
      payloads.add(
        CycleVaultPayload(
          name: entry.name,
          kind: entry.kind,
          bytes: List<int>.unmodifiable(plaintext),
        ),
      );
    }

    return CycleVaultRestoreResult(
      document: document,
      payloads: List.unmodifiable(payloads),
    );
  }
}
