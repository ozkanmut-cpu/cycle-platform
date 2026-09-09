import 'dart:convert';

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
      final expectedAad = utf8.encode(
        'cyclevault/v1|${document.manifest.snapshotId}|${entry.kind}|${entry.name}',
      );
      if (!_constantTimeEquals(entry.envelope.associatedData, expectedAad)) {
        throw const FormatException('Cycle vault entry context mismatch.');
      }

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

  bool _constantTimeEquals(List<int>? actual, List<int> expected) {
    if (actual == null || actual.length != expected.length) return false;
    var difference = 0;
    for (var index = 0; index < expected.length; index += 1) {
      difference |= actual[index] ^ expected[index];
    }
    return difference == 0;
  }
}
