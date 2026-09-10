import 'dart:convert';

class PairingInvitation {
  const PairingInvitation({
    required this.ownerId,
    required this.recipientId,
    required this.keyEnvelopeId,
    required this.nonce,
    required this.expiresAt,
  });

  final String ownerId;
  final String recipientId;
  final String keyEnvelopeId;
  final String nonce;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime at) => !at.toUtc().isBefore(expiresAt.toUtc());
}

class PairingQrCodec {
  const PairingQrCodec();

  String encode(PairingInvitation invitation) {
    final payload = <String, Object?>{
      'v': 1,
      'ownerId': invitation.ownerId,
      'recipientId': invitation.recipientId,
      'keyEnvelopeId': invitation.keyEnvelopeId,
      'nonce': invitation.nonce,
      'expiresAt': invitation.expiresAt.toUtc().toIso8601String(),
    };
    return base64Url
        .encode(utf8.encode(jsonEncode(payload)))
        .replaceAll('=', '');
  }

  PairingInvitation decode(String encoded, {required DateTime now}) {
    final padding = '=' * ((4 - encoded.length % 4) % 4);
    final decoded =
        jsonDecode(utf8.decode(base64Url.decode('$encoded$padding')));
    if (decoded is! Map) {
      throw const FormatException('Invalid pairing payload.');
    }
    final map = Map<String, Object?>.from(decoded);
    if (map['v'] != 1) {
      throw const FormatException('Unsupported pairing payload version.');
    }
    final invitation = PairingInvitation(
      ownerId: _required(map, 'ownerId'),
      recipientId: _required(map, 'recipientId'),
      keyEnvelopeId: _required(map, 'keyEnvelopeId'),
      nonce: _required(map, 'nonce'),
      expiresAt: DateTime.parse(_required(map, 'expiresAt')).toUtc(),
    );
    if (invitation.isExpiredAt(now)) {
      throw const FormatException('Pairing invitation expired.');
    }
    return invitation;
  }

  String _required(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Pairing payload is missing $key.');
    }
    return value;
  }
}
