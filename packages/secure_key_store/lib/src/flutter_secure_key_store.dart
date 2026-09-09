import 'dart:convert';
import 'dart:math';

import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FlutterSecureKeyStore implements SecureKeyStore {
  FlutterSecureKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _prefix = 'cycle.key.';
  static const _activePrefix = 'cycle.active.';

  @override
  Future<KeyEnvelope> createKey(KeyPurpose purpose) async {
    final current = await getActiveKey(purpose);
    if (current != null) return current;

    final version = 1;
    final envelope = await _generateEnvelope(purpose, version: version);
    await _persist(envelope);
    return envelope;
  }

  @override
  Future<KeyEnvelope?> getActiveKey(KeyPurpose purpose) async {
    final id = await _storage.read(key: '$_activePrefix${purpose.name}');
    if (id == null) return null;
    return _readEnvelope(id);
  }

  @override
  Future<KeyEnvelope> rotateKey(KeyPurpose purpose) async {
    final current = await getActiveKey(purpose);
    final nextVersion = (current?.version ?? 0) + 1;
    final next = await _generateEnvelope(
      purpose,
      version: nextVersion,
      rotatedFromEnvelopeId: current?.id,
    );
    await _persist(next);
    if (current != null) {
      await revokeKey(current.id);
    }
    return next;
  }

  @override
  Future<void> revokeKey(String envelopeId) async {
    final envelope = await _readEnvelope(envelopeId);
    if (envelope == null) return;

    await _storage.delete(key: '$_prefix$envelopeId');
    final activeKey = '$_activePrefix${envelope.purpose.name}';
    final activeId = await _storage.read(key: activeKey);
    if (activeId == envelopeId) {
      await _storage.delete(key: activeKey);
    }
  }

  @override
  Future<void> destroyAllKeys() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_prefix) || key.startsWith(_activePrefix)) {
        await _storage.delete(key: key);
      }
    }
  }

  Future<KeyEnvelope> _generateEnvelope(
    KeyPurpose purpose, {
    required int version,
    String? rotatedFromEnvelopeId,
  }) async {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final id =
        '${purpose.name}-$version-${DateTime.now().microsecondsSinceEpoch}';
    return KeyEnvelope(
      id: id,
      purpose: purpose,
      version: version,
      wrappedKey: List.unmodifiable(bytes),
      createdAt: DateTime.now().toUtc(),
      rotatedFromEnvelopeId: rotatedFromEnvelopeId,
    );
  }

  Future<void> _persist(KeyEnvelope envelope) async {
    final payload = jsonEncode(<String, Object?>{
      'id': envelope.id,
      'purpose': envelope.purpose.name,
      'version': envelope.version,
      'key': base64Encode(envelope.wrappedKey),
      'createdAt': envelope.createdAt.toUtc().toIso8601String(),
      'rotatedFromEnvelopeId': envelope.rotatedFromEnvelopeId,
    });
    await _storage.write(key: '$_prefix${envelope.id}', value: payload);
    await _storage.write(
      key: '$_activePrefix${envelope.purpose.name}',
      value: envelope.id,
    );
  }

  Future<KeyEnvelope?> _readEnvelope(String id) async {
    final raw = await _storage.read(key: '$_prefix$id');
    if (raw == null) return null;
    final map = Map<String, Object?>.from(jsonDecode(raw) as Map);
    final purpose = KeyPurpose.values.firstWhere(
      (value) => value.name == map['purpose']! as String,
    );
    return KeyEnvelope(
      id: map['id']! as String,
      purpose: purpose,
      version: map['version']! as int,
      wrappedKey: base64Decode(map['key']! as String),
      createdAt: DateTime.parse(map['createdAt']! as String),
      rotatedFromEnvelopeId: map['rotatedFromEnvelopeId'] as String?,
    );
  }
}
