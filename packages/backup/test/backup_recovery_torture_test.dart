import 'dart:convert';

import 'package:cycle_backup/cycle_backup.dart';
import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:test/test.dart';

void main() {
  const codec = CycleVaultCodec();

  CycleVaultEntry entry({
    String name = 'database.snapshot',
    String keyEnvelopeId = 'backup-key-v1',
  }) =>
      CycleVaultEntry(
        name: name,
        kind: 'database',
        envelope: CiphertextEnvelope(
          algorithm: 'AES-256-GCM',
          keyEnvelopeId: keyEnvelopeId,
          nonce: const <int>[1, 2, 3],
          ciphertext: const <int>[4, 5, 6],
          authenticationTag: const <int>[7, 8, 9],
          associatedData: utf8.encode(
            'cyclevault/v1|snapshot-torture|database|$name',
          ),
        ),
      );

  List<int> validBytes({int schemaVersion = 2}) => codec.encode(
        snapshotId: 'snapshot-torture',
        createdAt: DateTime.utc(2026, 9, 10, 17),
        schemaVersion: schemaVersion,
        recordCount: 2,
        attachmentCount: 0,
        rawSensorEntryCount: 0,
        entries: <CycleVaultEntry>[entry()],
      );

  group('corruption matrix', () {
    test('rejects malformed roots deterministically', () {
      final cases = <List<int>>[
        utf8.encode('null'),
        utf8.encode('[]'),
        utf8.encode('{}'),
        utf8.encode('{"magic":"WRONG"}'),
      ];

      for (final bytes in cases) {
        expect(() => codec.decodeAndVerify(bytes), throwsA(anything));
        expect(() => codec.decodeAndVerify(bytes), throwsA(anything));
      }
    });

    test('detects manifest and encrypted-entry tampering', () {
      final original = validBytes();
      final base = Map<String, Object?>.from(
        jsonDecode(utf8.decode(original)) as Map,
      );

      final manifestTampered = Map<String, Object?>.from(base);
      final manifest = Map<String, Object?>.from(
        manifestTampered['manifest']! as Map,
      );
      manifest['recordCount'] = 999;
      manifestTampered['manifest'] = manifest;

      final entryTampered = Map<String, Object?>.from(base);
      final entries = Map<String, Object?>.from(entryTampered['entries']! as Map);
      final database = Map<String, Object?>.from(
        entries['database.snapshot']! as Map,
      );
      database['ciphertext'] = base64Encode(const <int>[99, 98, 97]);
      entries['database.snapshot'] = database;
      entryTampered['entries'] = entries;

      for (final document in <Map<String, Object?>>[
        manifestTampered,
        entryTampered,
      ]) {
        final bytes = utf8.encode(jsonEncode(document));
        expect(() => codec.decodeAndVerify(bytes), throwsFormatException);
      }
    });

    test('rejects missing entry declared by the manifest', () {
      final document = Map<String, Object?>.from(
        jsonDecode(utf8.decode(validBytes())) as Map,
      );
      document['entries'] = <String, Object?>{};

      expect(
        () => codec.decodeAndVerify(utf8.encode(jsonEncode(document))),
        throwsFormatException,
      );
    });
  });

  group('fail-closed restore', () {
    test('unsupported schema fails before any decryption attempt', () async {
      var decryptAttempts = 0;
      final restorer = CycleVaultRestorer(
        cipher: _CountingCipher(onDecrypt: () => decryptAttempts += 1),
        maxSupportedSchemaVersion: 2,
      );

      await expectLater(
        restorer.restore(validBytes(schemaVersion: 99)),
        throwsStateError,
      );
      expect(decryptAttempts, 0);
    });

    test('missing backup key never returns a restore result', () async {
      final backupKey = List<int>.filled(32, 7);
      final bytes = await CycleVaultBuilder(
        cipher: AesGcmAuthenticatedCipher(
          keyResolver: (_) async => backupKey,
        ),
        backupKeyEnvelopeId: 'backup-key-v1',
      ).build(
        snapshotId: 'snapshot-torture',
        createdAt: DateTime.utc(2026, 9, 10, 17),
        schemaVersion: 2,
        recordCount: 1,
        attachmentCount: 0,
        rawSensorEntryCount: 0,
        payloads: const <CycleVaultPayload>[
          CycleVaultPayload(
            name: 'database.snapshot',
            kind: 'database',
            bytes: <int>[1, 2, 3],
          ),
        ],
      );
      final restorer = CycleVaultRestorer(
        cipher: AesGcmAuthenticatedCipher(
          keyResolver: (_) async => throw StateError('missing backup key'),
        ),
        maxSupportedSchemaVersion: 2,
      );

      await expectLater(restorer.restore(bytes), throwsStateError);
    });

    test('wrong backup key never returns decrypted payloads', () async {
      final encryptKey = List<int>.filled(32, 7);
      final wrongKey = List<int>.filled(32, 8);
      final bytes = await CycleVaultBuilder(
        cipher: AesGcmAuthenticatedCipher(
          keyResolver: (_) async => encryptKey,
        ),
        backupKeyEnvelopeId: 'backup-key-v1',
      ).build(
        snapshotId: 'snapshot-torture',
        createdAt: DateTime.utc(2026, 9, 10, 17),
        schemaVersion: 2,
        recordCount: 1,
        attachmentCount: 0,
        rawSensorEntryCount: 0,
        payloads: const <CycleVaultPayload>[
          CycleVaultPayload(
            name: 'database.snapshot',
            kind: 'database',
            bytes: <int>[1, 2, 3],
          ),
        ],
      );
      final restorer = CycleVaultRestorer(
        cipher: AesGcmAuthenticatedCipher(
          keyResolver: (_) async => wrongKey,
        ),
        maxSupportedSchemaVersion: 2,
      );

      await expectLater(restorer.restore(bytes), throwsA(anything));
    });

    test('one bad entry prevents a successful multi-entry restore', () async {
      final key = List<int>.filled(32, 5);
      final cipher = AesGcmAuthenticatedCipher(keyResolver: (_) async => key);
      final goodEnvelope = await cipher.encrypt(
        plaintext: const <int>[1, 2, 3],
        keyEnvelopeId: 'backup-key-v1',
        associatedData: utf8.encode(
          'cyclevault/v1|snapshot-atomic|database|database.snapshot',
        ),
      );
      final badEnvelope = CiphertextEnvelope(
        algorithm: goodEnvelope.algorithm,
        keyEnvelopeId: goodEnvelope.keyEnvelopeId,
        nonce: goodEnvelope.nonce,
        ciphertext: goodEnvelope.ciphertext,
        authenticationTag: goodEnvelope.authenticationTag,
        associatedData: utf8.encode('wrong-context'),
      );
      final document = CycleVaultDocument(
        manifest: CycleVaultManifest(
          formatVersion: 1,
          snapshotId: 'snapshot-atomic',
          createdAt: DateTime.utc(2026, 9, 10, 17),
          schemaVersion: 2,
          recordCount: 2,
          attachmentCount: 0,
          rawSensorEntryCount: 0,
          entryHashes: const <String, String>{},
          integrityHash: 'test-only',
        ),
        entries: <CycleVaultEntry>[
          CycleVaultEntry(
            name: 'database.snapshot',
            kind: 'database',
            envelope: goodEnvelope,
          ),
          CycleVaultEntry(
            name: 'second.snapshot',
            kind: 'database',
            envelope: badEnvelope,
          ),
        ],
      );
      final restorer = CycleVaultRestorer(
        cipher: cipher,
        maxSupportedSchemaVersion: 2,
        codec: _FixedCodec(document),
      );

      await expectLater(restorer.restore(const <int>[]), throwsFormatException);
    });
  });

  group('recovery drill failure states', () {
    test('reports integrity failure without checking key recovery', () async {
      var keyChecks = 0;
      final bytes = List<int>.from(validBytes())..add(0);
      final drill = RecoveryDrill(
        maxSupportedSchemaVersion: 2,
        keyRecoverabilityCheck: (_) async {
          keyChecks += 1;
          return true;
        },
      );

      final result = await drill.run(bytes);

      expect(result.passed, isFalse);
      expect(result.integrityValid, isFalse);
      expect(result.schemaSupported, isFalse);
      expect(result.keyRecoverable, isFalse);
      expect(keyChecks, 0);
    });

    test('reports unsupported schema without checking key recovery', () async {
      var keyChecks = 0;
      final drill = RecoveryDrill(
        maxSupportedSchemaVersion: 2,
        keyRecoverabilityCheck: (_) async {
          keyChecks += 1;
          return true;
        },
      );

      final result = await drill.run(validBytes(schemaVersion: 99));

      expect(result.passed, isFalse);
      expect(result.integrityValid, isTrue);
      expect(result.schemaSupported, isFalse);
      expect(result.keyRecoverable, isFalse);
      expect(keyChecks, 0);
    });

    test('reports unrecoverable key deterministically', () async {
      final drill = RecoveryDrill(
        maxSupportedSchemaVersion: 2,
        keyRecoverabilityCheck: (_) async => false,
      );

      final first = await drill.run(validBytes());
      final second = await drill.run(validBytes());

      expect(first.passed, isFalse);
      expect(first.integrityValid, isTrue);
      expect(first.schemaSupported, isTrue);
      expect(first.keyRecoverable, isFalse);
      expect(first.reason, 'Backup encryption key is not recoverable.');
      expect(second.integrityValid, first.integrityValid);
      expect(second.schemaSupported, first.schemaSupported);
      expect(second.keyRecoverable, first.keyRecoverable);
      expect(second.reason, first.reason);
    });
  });
}

class _FixedCodec extends CycleVaultCodec {
  const _FixedCodec(this.document);

  final CycleVaultDocument document;

  @override
  CycleVaultDocument decodeAndVerify(List<int> bytes) => document;
}

class _CountingCipher implements AuthenticatedCipher {
  _CountingCipher({required this.onDecrypt});

  final void Function() onDecrypt;

  @override
  Future<CiphertextEnvelope> encrypt({
    required List<int> plaintext,
    required String keyEnvelopeId,
    List<int>? associatedData,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> decrypt(CiphertextEnvelope envelope) async {
    onDecrypt();
    return const <int>[];
  }
}
