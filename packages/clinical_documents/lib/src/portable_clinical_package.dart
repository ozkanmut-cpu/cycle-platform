import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

class PortableClinicalExportAuthorization {
  const PortableClinicalExportAuthorization({
    required this.patientId,
    required this.exportAllowed,
  });

  final String patientId;
  final bool exportAllowed;
}

enum PortableClinicalEntryKind { clinicalSnapshot, document, fhirBundle }

class PortableClinicalPackageException implements Exception {
  const PortableClinicalPackageException(this.message);

  final String message;

  @override
  String toString() => 'PortableClinicalPackageException: $message';
}

class PortableClinicalEntry {
  PortableClinicalEntry({
    required this.id,
    required this.patientId,
    required this.path,
    required this.kind,
    required this.mediaType,
    required this.payload,
    required this.sha256,
    required this.schemaVersion,
    this.provenanceIds = const <String>[],
    this.evidenceIds = const <String>[],
  }) {
    _requireText(id, 'entry id');
    _requireText(patientId, 'entry patientId');
    _requireText(path, 'entry path');
    _requireText(mediaType, 'entry mediaType');
    _requireText(sha256, 'entry sha256');
    if (schemaVersion <= 0) {
      throw const PortableClinicalPackageException(
        'entry schemaVersion must be positive',
      );
    }
    if (provenanceIds.any((value) => value.trim().isEmpty) ||
        evidenceIds.any((value) => value.trim().isEmpty)) {
      throw const PortableClinicalPackageException(
        'provenance and evidence ids must not be blank',
      );
    }
  }

  final String id;
  final String patientId;
  final String path;
  final PortableClinicalEntryKind kind;
  final String mediaType;
  final List<int> payload;
  final String sha256;
  final int schemaVersion;
  final List<String> provenanceIds;
  final List<String> evidenceIds;
}

class PortableClinicalManifestEntry {
  const PortableClinicalManifestEntry({
    required this.id,
    required this.path,
    required this.kind,
    required this.mediaType,
    required this.sha256,
    required this.byteLength,
    required this.schemaVersion,
    required this.provenanceIds,
    required this.evidenceIds,
  });

  final String id;
  final String path;
  final PortableClinicalEntryKind kind;
  final String mediaType;
  final String sha256;
  final int byteLength;
  final int schemaVersion;
  final List<String> provenanceIds;
  final List<String> evidenceIds;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'path': path,
        'kind': kind.name,
        'mediaType': mediaType,
        'sha256': sha256,
        'byteLength': byteLength,
        'schemaVersion': schemaVersion,
        'provenanceIds': provenanceIds,
        'evidenceIds': evidenceIds,
      };
}

class PortableClinicalPackageManifest {
  const PortableClinicalPackageManifest({
    required this.packageId,
    required this.patientId,
    required this.createdAt,
    required this.schemaVersion,
    required this.entries,
  });

  final String packageId;
  final String patientId;
  final DateTime createdAt;
  final int schemaVersion;
  final List<PortableClinicalManifestEntry> entries;

  Map<String, Object?> toJson() => <String, Object?>{
        'packageId': packageId,
        'patientId': patientId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'schemaVersion': schemaVersion,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      };

  String canonicalJson() => jsonEncode(toJson());
}

class PortableClinicalPackage {
  const PortableClinicalPackage({
    required this.manifest,
    required this.payloadsByPath,
  });

  final PortableClinicalPackageManifest manifest;
  final Map<String, List<int>> payloadsByPath;
}

class PortableClinicalPackageBuilder {
  const PortableClinicalPackageBuilder();

  PortableClinicalPackage build({
    required String packageId,
    required String patientId,
    required DateTime createdAt,
    required PortableClinicalExportAuthorization authorization,
    required Iterable<PortableClinicalEntry> entries,
    int schemaVersion = 1,
  }) {
    _requireText(packageId, 'package id');
    _requireText(patientId, 'patient id');
    if (schemaVersion <= 0) {
      throw const PortableClinicalPackageException(
        'package schemaVersion must be positive',
      );
    }

    final normalizedPatientId = patientId.trim();
    if (!authorization.exportAllowed ||
        authorization.patientId.trim() != normalizedPatientId) {
      throw const PortableClinicalPackageException(
        'explicit export authorization is required for this patient',
      );
    }

    final input = entries.toList(growable: false);
    final ids = <String>{};
    final paths = <String>{};
    for (final entry in input) {
      if (entry.patientId.trim() != normalizedPatientId) {
        throw const PortableClinicalPackageException(
          'portable package cannot mix patients',
        );
      }
      if (!ids.add(entry.id.trim())) {
        throw PortableClinicalPackageException(
          'duplicate entry id: ${entry.id.trim()}',
        );
      }
      if (!paths.add(entry.path.trim())) {
        throw PortableClinicalPackageException(
          'duplicate entry path: ${entry.path.trim()}',
        );
      }
      final actualDigest = sha256Hex(entry.payload);
      if (!_constantTimeEquals(
        actualDigest,
        entry.sha256.trim().toLowerCase(),
      )) {
        throw PortableClinicalPackageException(
          'checksum mismatch for entry ${entry.id.trim()}',
        );
      }
    }

    final sorted = [...input]
      ..sort((a, b) {
        final pathCompare = a.path.trim().compareTo(b.path.trim());
        return pathCompare != 0
            ? pathCompare
            : a.id.trim().compareTo(b.id.trim());
      });

    final manifestEntries = sorted
        .map(
          (entry) => PortableClinicalManifestEntry(
            id: entry.id.trim(),
            path: entry.path.trim(),
            kind: entry.kind,
            mediaType: entry.mediaType.trim(),
            sha256: entry.sha256.trim().toLowerCase(),
            byteLength: entry.payload.length,
            schemaVersion: entry.schemaVersion,
            provenanceIds: _sortedUnique(entry.provenanceIds),
            evidenceIds: _sortedUnique(entry.evidenceIds),
          ),
        )
        .toList(growable: false);

    return PortableClinicalPackage(
      manifest: PortableClinicalPackageManifest(
        packageId: packageId.trim(),
        patientId: normalizedPatientId,
        createdAt: createdAt.toUtc(),
        schemaVersion: schemaVersion,
        entries: List.unmodifiable(manifestEntries),
      ),
      payloadsByPath: Map.unmodifiable(<String, List<int>>{
        for (final entry in sorted)
          entry.path.trim(): List<int>.unmodifiable(entry.payload),
      }),
    );
  }
}

String sha256Hex(List<int> input) => crypto.sha256.convert(input).toString();

List<String> _sortedUnique(Iterable<String> values) {
  final result = values.map((value) => value.trim()).toSet().toList()..sort();
  return List.unmodifiable(result);
}

void _requireText(String value, String field) {
  if (value.trim().isEmpty) {
    throw PortableClinicalPackageException('$field must not be blank');
  }
}

bool _constantTimeEquals(String left, String right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var i = 0; i < left.length; i++) {
    difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
  }
  return difference == 0;
}
