import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:path/path.dart' as p;

class EncryptedFileVault implements BinaryVault {
  EncryptedFileVault({
    required Directory directory,
    required AuthenticatedCipher cipher,
    required String keyEnvelopeId,
    required String namespace,
  }) : _directory = directory,
       _cipher = cipher,
       _keyEnvelopeId = keyEnvelopeId,
       _namespace = namespace;

  final Directory _directory;
  final AuthenticatedCipher _cipher;
  final String _keyEnvelopeId;
  final String _namespace;

  @override
  Future<void> write(VaultBlob blob) async {
    await _directory.create(recursive: true);

    final plaintext = utf8.encode(
      jsonEncode(<String, Object?>{
        'id': blob.id,
        'bytes': base64Encode(blob.bytes),
        'createdAt': blob.createdAt.toUtc().toIso8601String(),
        'contentType': blob.contentType,
        'originalName': blob.originalName,
        'metadata': blob.metadata,
      }),
    );
    final aad = _associatedData(blob.id);
    final envelope = await _cipher.encrypt(
      plaintext: plaintext,
      keyEnvelopeId: _keyEnvelopeId,
      associatedData: aad,
    );

    final encoded = jsonEncode(<String, Object?>{
      'version': 1,
      'algorithm': envelope.algorithm,
      'keyEnvelopeId': envelope.keyEnvelopeId,
      'nonce': base64Encode(envelope.nonce),
      'ciphertext': base64Encode(envelope.ciphertext),
      'authenticationTag': base64Encode(envelope.authenticationTag),
    });

    final target = _fileFor(blob.id);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(encoded, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);
  }

  @override
  Future<VaultBlob?> read(String id) async {
    final file = _fileFor(id);
    if (!await file.exists()) return null;

    final raw = jsonDecode(await file.readAsString());
    final map = Map<String, Object?>.from(raw as Map);
    final envelope = CiphertextEnvelope(
      algorithm: map['algorithm']! as String,
      keyEnvelopeId: map['keyEnvelopeId']! as String,
      nonce: base64Decode(map['nonce']! as String),
      ciphertext: base64Decode(map['ciphertext']! as String),
      authenticationTag: base64Decode(map['authenticationTag']! as String),
      associatedData: _associatedData(id),
    );
    final plaintext = await _cipher.decrypt(envelope);
    final payload = Map<String, Object?>.from(
      jsonDecode(utf8.decode(plaintext)) as Map,
    );

    if (payload['id'] != id) {
      throw StateError('Vault blob identity mismatch.');
    }

    return VaultBlob(
      id: payload['id']! as String,
      bytes: base64Decode(payload['bytes']! as String),
      createdAt: DateTime.parse(payload['createdAt']! as String),
      contentType: payload['contentType'] as String?,
      originalName: payload['originalName'] as String?,
      metadata: payload['metadata'] == null
          ? const <String, Object?>{}
          : Map<String, Object?>.from(payload['metadata']! as Map),
    );
  }

  @override
  Future<void> delete(String id) async {
    final file = _fileFor(id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<bool> contains(String id) => _fileFor(id).exists();

  File _fileFor(String id) {
    final digest = sha256.convert(utf8.encode('$_namespace|$id')).toString();
    return File(p.join(_directory.path, '$digest.cycleblob'));
  }

  List<int> _associatedData(String id) {
    return utf8.encode('cycle-vault/v1|$_namespace|$id');
  }
}

class EncryptedAttachmentVault extends EncryptedFileVault
    implements AttachmentVault {
  EncryptedAttachmentVault({
    required super.directory,
    required super.cipher,
    required super.keyEnvelopeId,
  }) : super(namespace: 'attachment');
}

class EncryptedRawSensorVault extends EncryptedFileVault
    implements RawSensorVault {
  EncryptedRawSensorVault({
    required super.directory,
    required super.cipher,
    required super.keyEnvelopeId,
  }) : super(namespace: 'raw-sensor');
}
