import 'dart:convert';

import 'package:cycle_crypto/cycle_crypto.dart';

import 'cycle_vault.dart';

class CycleVaultPayload {
  const CycleVaultPayload({
    required this.name,
    required this.kind,
    required this.bytes,
  });

  final String name;
  final String kind;
  final List<int> bytes;
}

class CycleVaultBuilder {
  const CycleVaultBuilder({
    required this.cipher,
    required this.backupKeyEnvelopeId,
    this.codec = const CycleVaultCodec(),
  });

  final AuthenticatedCipher cipher;
  final String backupKeyEnvelopeId;
  final CycleVaultCodec codec;

  Future<List<int>> build({
    required String snapshotId,
    required DateTime createdAt,
    required int schemaVersion,
    required int recordCount,
    required int attachmentCount,
    required int rawSensorEntryCount,
    required List<CycleVaultPayload> payloads,
  }) async {
    final entries = <CycleVaultEntry>[];
    for (final payload in payloads) {
      final aad = utf8.encode(
        'cyclevault/v1|$snapshotId|${payload.kind}|${payload.name}',
      );
      final envelope = await cipher.encrypt(
        plaintext: payload.bytes,
        keyEnvelopeId: backupKeyEnvelopeId,
        associatedData: aad,
      );
      entries.add(
        CycleVaultEntry(
          name: payload.name,
          kind: payload.kind,
          envelope: envelope,
        ),
      );
    }

    return codec.encode(
      snapshotId: snapshotId,
      createdAt: createdAt,
      schemaVersion: schemaVersion,
      recordCount: recordCount,
      attachmentCount: attachmentCount,
      rawSensorEntryCount: rawSensorEntryCount,
      entries: entries,
    );
  }
}
