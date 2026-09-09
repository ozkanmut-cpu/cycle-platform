import 'dart:convert';

import 'package:cycle_backup/cycle_backup.dart';
import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:test/test.dart';

void main() {
  const codec = CycleVaultCodec();

  CycleVaultEntry entry({String name = 'database'}) => CycleVaultEntry(
        name: name,
        kind: 'database',
        envelope: const CiphertextEnvelope(
          algorithm: 'AES-256-GCM',
          keyEnvelopeId: 'backup-key-v1',
          nonce: <int>[1, 2, 3],
          ciphertext: <int>[4, 5, 6],
          authenticationTag: <int>[7, 8, 9],
          associatedData: <int>[10],
        ),
      );

  test('round-trips a verified .cyclevault document', () {
    final bytes = codec.encode(
      snapshotId: 'snapshot-1',
      createdAt: DateTime.utc(2026, 9, 9, 16),
      schemaVersion: 2,
      recordCount: 42,
      attachmentCount: 3,
      rawSensorEntryCount: 1,
      entries: <CycleVaultEntry>[entry()],
    );

    final decoded = codec.decodeAndVerify(bytes);

    expect(decoded.manifest.snapshotId, 'snapshot-1');
    expect(decoded.manifest.recordCount, 42);
    expect(decoded.entries.single.envelope.ciphertext, <int>[4, 5, 6]);
    expect(decoded.manifest.integrityHash, startsWith('sha256:'));
  });

  test('tampering invalidates .cyclevault integrity', () {
    final bytes = codec.encode(
      snapshotId: 'snapshot-1',
      createdAt: DateTime.utc(2026, 9, 9, 16),
      schemaVersion: 1,
      recordCount: 1,
      attachmentCount: 0,
      rawSensorEntryCount: 0,
      entries: <CycleVaultEntry>[entry()],
    );
    final document = Map<String, Object?>.from(
      jsonDecode(utf8.decode(bytes)) as Map,
    );
    final entries = Map<String, Object?>.from(document['entries']! as Map);
    final database = Map<String, Object?>.from(entries['database']! as Map);
    database['ciphertext'] = base64Encode(<int>[99, 98, 97]);
    entries['database'] = database;
    document['entries'] = entries;

    expect(
      () => codec.decodeAndVerify(utf8.encode(jsonEncode(document))),
      throwsFormatException,
    );
  });

  test('recovery drill reports schema and key readiness', () async {
    final bytes = codec.encode(
      snapshotId: 'snapshot-2',
      createdAt: DateTime.utc(2026, 9, 9, 16),
      schemaVersion: 2,
      recordCount: 12,
      attachmentCount: 2,
      rawSensorEntryCount: 4,
      entries: <CycleVaultEntry>[entry()],
    );
    final drill = RecoveryDrill(
      maxSupportedSchemaVersion: 2,
      keyRecoverabilityCheck: (_) async => true,
    );

    final result = await drill.run(bytes);

    expect(result.passed, isTrue);
    expect(result.integrityValid, isTrue);
    expect(result.recordCount, 12);
    expect(result.attachmentCount, 2);
    expect(result.rawSensorEntryCount, 4);
  });

  test('rejects unsafe or duplicate entry names', () {
    expect(
      () => codec.encode(
        snapshotId: 'snapshot-3',
        createdAt: DateTime.utc(2026, 9, 9, 16),
        schemaVersion: 1,
        recordCount: 0,
        attachmentCount: 0,
        rawSensorEntryCount: 0,
        entries: <CycleVaultEntry>[entry(name: '../database')],
      ),
      throwsArgumentError,
    );
  });
}
