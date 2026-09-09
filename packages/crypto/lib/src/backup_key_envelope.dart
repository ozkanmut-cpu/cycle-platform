import 'authenticated_cipher.dart';

class BackupKeyEnvelope {
  const BackupKeyEnvelope({
    required this.version,
    required this.wrappingMethod,
    required this.wrappedKey,
    required this.createdAt,
    this.kdf,
    this.kdfSalt,
    this.kdfParameters = const <String, Object?>{},
  });

  final int version;
  final String wrappingMethod;
  final CiphertextEnvelope wrappedKey;
  final DateTime createdAt;
  final String? kdf;
  final List<int>? kdfSalt;
  final Map<String, Object?> kdfParameters;
}

class BackupKeyEnvelopeService {
  const BackupKeyEnvelopeService(this._cipher);

  final AuthenticatedCipher _cipher;

  Future<BackupKeyEnvelope> wrap({
    required List<int> backupKey,
    required String wrappingKeyEnvelopeId,
    required String wrappingMethod,
    String? kdf,
    List<int>? kdfSalt,
    Map<String, Object?> kdfParameters = const <String, Object?>{},
  }) async {
    if (backupKey.length != 32) {
      throw ArgumentError.value(
        backupKey.length,
        'backupKey.length',
        'Backup key must be 256 bits.',
      );
    }

    final aad = <int>[
      ...'cycle-backup-key-envelope/v1|$wrappingMethod'.codeUnits,
    ];
    final wrapped = await _cipher.encrypt(
      plaintext: backupKey,
      keyEnvelopeId: wrappingKeyEnvelopeId,
      associatedData: aad,
    );

    return BackupKeyEnvelope(
      version: 1,
      wrappingMethod: wrappingMethod,
      wrappedKey: wrapped,
      createdAt: DateTime.now().toUtc(),
      kdf: kdf,
      kdfSalt: kdfSalt == null ? null : List<int>.unmodifiable(kdfSalt),
      kdfParameters: Map<String, Object?>.unmodifiable(kdfParameters),
    );
  }

  Future<List<int>> unwrap(BackupKeyEnvelope envelope) async {
    if (envelope.version != 1) {
      throw ArgumentError.value(
        envelope.version,
        'envelope.version',
        'Unsupported backup key envelope version.',
      );
    }
    return _cipher.decrypt(envelope.wrappedKey);
  }
}
