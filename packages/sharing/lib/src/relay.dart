import 'dart:convert';

import 'package:cycle_crypto/cycle_crypto.dart';

class OpaqueRelayEnvelope {
  const OpaqueRelayEnvelope({
    required this.messageId,
    required this.ownerId,
    required this.recipientId,
    required this.keyEnvelopeId,
    required this.ciphertext,
    required this.createdAt,
    required this.kind,
  });

  final String messageId;
  final String ownerId;
  final String recipientId;
  final String keyEnvelopeId;
  final CiphertextEnvelope ciphertext;
  final DateTime createdAt;
  final String kind;

  Map<String, Object?> toOpaqueMap() => <String, Object?>{
        'messageId': messageId,
        'ownerId': ownerId,
        'recipientId': recipientId,
        'keyEnvelopeId': keyEnvelopeId,
        'kind': kind,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'algorithm': ciphertext.algorithm,
        'nonce': base64Url.encode(ciphertext.nonce),
        'ciphertext': base64Url.encode(ciphertext.ciphertext),
        'authenticationTag': base64Url.encode(ciphertext.authenticationTag),
        'associatedData': ciphertext.associatedData == null
            ? null
            : base64Url.encode(ciphertext.associatedData!),
      };
}

class SharingTransport {
  const SharingTransport(this.cipher);

  final AuthenticatedCipher cipher;

  Future<OpaqueRelayEnvelope> encryptForRecipient({
    required String messageId,
    required String ownerId,
    required String recipientId,
    required String keyEnvelopeId,
    required List<int> plaintext,
    required DateTime createdAt,
    String kind = 'shared-record',
  }) async {
    final associatedData = utf8.encode(
      '$messageId|$ownerId|$recipientId|$kind',
    );
    final encrypted = await cipher.encrypt(
      plaintext: plaintext,
      keyEnvelopeId: keyEnvelopeId,
      associatedData: associatedData,
    );
    return OpaqueRelayEnvelope(
      messageId: messageId,
      ownerId: ownerId,
      recipientId: recipientId,
      keyEnvelopeId: keyEnvelopeId,
      ciphertext: encrypted,
      createdAt: createdAt,
      kind: kind,
    );
  }

  Future<List<int>> decryptForRecipient({
    required OpaqueRelayEnvelope envelope,
    required String recipientId,
  }) {
    if (envelope.recipientId != recipientId) {
      throw StateError('Relay envelope belongs to a different recipient.');
    }
    return cipher.decrypt(envelope.ciphertext);
  }

  Future<OpaqueRelayEnvelope> encryptBlindBackup({
    required String backupId,
    required String ownerId,
    required String recipientId,
    required String keyEnvelopeId,
    required List<int> cycleVaultBytes,
    required DateTime createdAt,
  }) {
    return encryptForRecipient(
      messageId: backupId,
      ownerId: ownerId,
      recipientId: recipientId,
      keyEnvelopeId: keyEnvelopeId,
      plaintext: cycleVaultBytes,
      createdAt: createdAt,
      kind: 'blind-backup',
    );
  }
}
