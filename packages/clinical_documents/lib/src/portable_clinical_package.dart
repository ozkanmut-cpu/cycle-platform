import 'dart:convert';

/// A fail-closed authorization supplied by the caller at export time.
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

  /// Canonical JSON: insertion order is fixed by [toJson], while all list
  /// members are sorted by the builder before this method is reached.
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
      if (!_constantTimeEquals(actualDigest, entry.sha256.trim().toLowerCase())) {
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

/// Minimal SHA-256 implementation kept local so this package has no runtime
/// dependency solely for manifest integrity verification.
String sha256Hex(List<int> input) {
  const initial = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  const k = <int>[
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
  ];
  final bytes = <int>[...input];
  final bitLength = bytes.length * 8;
  bytes.add(0x80);
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  for (var shift = 56; shift >= 0; shift -= 8) {
    bytes.add((bitLength >> shift) & 0xff);
  }

  final h = [...initial];
  for (var offset = 0; offset < bytes.length; offset += 64) {
    final w = List<int>.filled(64, 0);
    for (var i = 0; i < 16; i++) {
      final j = offset + i * 4;
      w[i] = ((bytes[j] << 24) | (bytes[j + 1] << 16) | (bytes[j + 2] << 8) | bytes[j + 3]) & 0xffffffff;
    }
    for (var i = 16; i < 64; i++) {
      final x = w[i - 15];
      final y = w[i - 2];
      final s0 = (_rotr(x, 7) ^ _rotr(x, 18) ^ (x >> 3)) & 0xffffffff;
      final s1 = (_rotr(y, 17) ^ _rotr(y, 19) ^ (y >> 10)) & 0xffffffff;
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = (_rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25)) & 0xffffffff;
      final ch = ((e & f) ^ ((~e) & g)) & 0xffffffff;
      final temp1 = (hh + s1 + ch + k[i] + w[i]) & 0xffffffff;
      final s0 = (_rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22)) & 0xffffffff;
      final maj = ((a & b) ^ (a & c) ^ (b & c)) & 0xffffffff;
      final temp2 = (s0 + maj) & 0xffffffff;
      hh = g; g = f; f = e; e = (d + temp1) & 0xffffffff;
      d = c; c = b; b = a; a = (temp1 + temp2) & 0xffffffff;
    }
    h[0] = (h[0] + a) & 0xffffffff; h[1] = (h[1] + b) & 0xffffffff;
    h[2] = (h[2] + c) & 0xffffffff; h[3] = (h[3] + d) & 0xffffffff;
    h[4] = (h[4] + e) & 0xffffffff; h[5] = (h[5] + f) & 0xffffffff;
    h[6] = (h[6] + g) & 0xffffffff; h[7] = (h[7] + hh) & 0xffffffff;
  }
  return h.map((value) => value.toRadixString(16).padLeft(8, '0')).join();
}

int _rotr(int value, int bits) =>
    ((value >> bits) | ((value << (32 - bits)) & 0xffffffff)) & 0xffffffff;
