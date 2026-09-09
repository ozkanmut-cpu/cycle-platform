import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:cycle_storage/cycle_storage.dart';

class CycleVaultEntry {
  const CycleVaultEntry({
    required this.name,
    required this.kind,
    required this.envelope,
  });

  final String name;
  final String kind;
  final CiphertextEnvelope envelope;
}

class CycleVaultManifest {
  const CycleVaultManifest({
    required this.formatVersion,
    required this.snapshotId,
    required this.createdAt,
    required this.schemaVersion,
    required this.recordCount,
    required this.attachmentCount,
    required this.rawSensorEntryCount,
    required this.entryHashes,
    required this.integrityHash,
  });

  final int formatVersion;
  final String snapshotId;
  final DateTime createdAt;
  final int schemaVersion;
  final int recordCount;
  final int attachmentCount;
  final int rawSensorEntryCount;
  final Map<String, String> entryHashes;
  final String integrityHash;

  RecoverySnapshot toRecoverySnapshot() => RecoverySnapshot(
        id: snapshotId,
        createdAt: createdAt,
        schemaVersion: schemaVersion,
        recordCount: recordCount,
        attachmentCount: attachmentCount,
        integrityHash: integrityHash,
      );
}

class CycleVaultDocument {
  const CycleVaultDocument({required this.manifest, required this.entries});

  final CycleVaultManifest manifest;
  final List<CycleVaultEntry> entries;
}

class CycleVaultCodec {
  const CycleVaultCodec();

  static const int currentFormatVersion = 1;

  List<int> encode({
    required String snapshotId,
    required DateTime createdAt,
    required int schemaVersion,
    required int recordCount,
    required int attachmentCount,
    required int rawSensorEntryCount,
    required List<CycleVaultEntry> entries,
  }) {
    _validateEntryNames(entries);
    final sortedEntries = [...entries]..sort((a, b) => a.name.compareTo(b.name));
    final encodedEntries = <String, Object?>{};
    final entryHashes = <String, String>{};

    for (final entry in sortedEntries) {
      final encoded = _encodeEntry(entry);
      encodedEntries[entry.name] = encoded;
      entryHashes[entry.name] = _sha256Canonical(encoded);
    }

    final unsignedManifest = <String, Object?>{
      'formatVersion': currentFormatVersion,
      'snapshotId': snapshotId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'schemaVersion': schemaVersion,
      'recordCount': recordCount,
      'attachmentCount': attachmentCount,
      'rawSensorEntryCount': rawSensorEntryCount,
      'entryHashes': entryHashes,
    };
    final integrityHash = _sha256Canonical(<String, Object?>{
      'manifest': unsignedManifest,
      'entries': encodedEntries,
    });

    final document = <String, Object?>{
      'magic': 'CYCLEVAULT',
      'manifest': <String, Object?>{
        ...unsignedManifest,
        'integrityHash': integrityHash,
      },
      'entries': encodedEntries,
    };
    return utf8.encode(jsonEncode(document));
  }

  CycleVaultDocument decodeAndVerify(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Invalid .cyclevault root document.');
    }
    final root = Map<String, Object?>.from(decoded);
    if (root['magic'] != 'CYCLEVAULT') {
      throw const FormatException('Invalid .cyclevault magic value.');
    }

    final manifestMap = Map<String, Object?>.from(root['manifest']! as Map);
    final formatVersion = manifestMap['formatVersion']! as int;
    if (formatVersion != currentFormatVersion) {
      throw FormatException('Unsupported .cyclevault format $formatVersion.');
    }

    final entriesMap = Map<String, Object?>.from(root['entries']! as Map);
    final entryHashes = Map<String, String>.from(manifestMap['entryHashes']! as Map);
    if (entriesMap.length != entryHashes.length ||
        !entriesMap.keys.toSet().containsAll(entryHashes.keys)) {
      throw const FormatException('Cycle vault entry manifest mismatch.');
    }

    for (final entry in entriesMap.entries) {
      final expected = entryHashes[entry.key];
      final actual = _sha256Canonical(entry.value);
      if (expected == null || expected != actual) {
        throw FormatException('Cycle vault entry integrity failed: ${entry.key}.');
      }
    }

    final unsignedManifest = <String, Object?>{
      'formatVersion': manifestMap['formatVersion'],
      'snapshotId': manifestMap['snapshotId'],
      'createdAt': manifestMap['createdAt'],
      'schemaVersion': manifestMap['schemaVersion'],
      'recordCount': manifestMap['recordCount'],
      'attachmentCount': manifestMap['attachmentCount'],
      'rawSensorEntryCount': manifestMap['rawSensorEntryCount'],
      'entryHashes': entryHashes,
    };
    final actualIntegrity = _sha256Canonical(<String, Object?>{
      'manifest': unsignedManifest,
      'entries': entriesMap,
    });
    final expectedIntegrity = manifestMap['integrityHash']! as String;
    if (actualIntegrity != expectedIntegrity) {
      throw const FormatException('Cycle vault manifest integrity failed.');
    }

    final entries = entriesMap.entries
        .map((entry) => _decodeEntry(entry.key, entry.value))
        .toList(growable: false);
    final manifest = CycleVaultManifest(
      formatVersion: formatVersion,
      snapshotId: manifestMap['snapshotId']! as String,
      createdAt: DateTime.parse(manifestMap['createdAt']! as String),
      schemaVersion: manifestMap['schemaVersion']! as int,
      recordCount: manifestMap['recordCount']! as int,
      attachmentCount: manifestMap['attachmentCount']! as int,
      rawSensorEntryCount: manifestMap['rawSensorEntryCount']! as int,
      entryHashes: Map.unmodifiable(entryHashes),
      integrityHash: expectedIntegrity,
    );
    return CycleVaultDocument(
      manifest: manifest,
      entries: List.unmodifiable(entries),
    );
  }

  Map<String, Object?> _encodeEntry(CycleVaultEntry entry) => <String, Object?>{
        'kind': entry.kind,
        'algorithm': entry.envelope.algorithm,
        'keyEnvelopeId': entry.envelope.keyEnvelopeId,
        'nonce': base64Encode(entry.envelope.nonce),
        'ciphertext': base64Encode(entry.envelope.ciphertext),
        'authenticationTag': base64Encode(entry.envelope.authenticationTag),
        'associatedData': entry.envelope.associatedData == null
            ? null
            : base64Encode(entry.envelope.associatedData!),
      };

  CycleVaultEntry _decodeEntry(String name, Object? raw) {
    final map = Map<String, Object?>.from(raw! as Map);
    return CycleVaultEntry(
      name: name,
      kind: map['kind']! as String,
      envelope: CiphertextEnvelope(
        algorithm: map['algorithm']! as String,
        keyEnvelopeId: map['keyEnvelopeId']! as String,
        nonce: base64Decode(map['nonce']! as String),
        ciphertext: base64Decode(map['ciphertext']! as String),
        authenticationTag: base64Decode(map['authenticationTag']! as String),
        associatedData: map['associatedData'] == null
            ? null
            : base64Decode(map['associatedData']! as String),
      ),
    );
  }

  void _validateEntryNames(List<CycleVaultEntry> entries) {
    final names = <String>{};
    for (final entry in entries) {
      if (entry.name.isEmpty || entry.name.contains('..') || entry.name.startsWith('/')) {
        throw ArgumentError.value(entry.name, 'entry.name', 'Unsafe vault entry name.');
      }
      if (!names.add(entry.name)) {
        throw ArgumentError.value(entry.name, 'entry.name', 'Duplicate vault entry name.');
      }
    }
  }

  String _sha256Canonical(Object? value) {
    return 'sha256:${sha256.convert(utf8.encode(_canonicalJson(value)))}';
  }

  String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    return jsonEncode(value);
  }
}
