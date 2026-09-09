import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'key_purpose.dart';

class KeyDeriver {
  const KeyDeriver();

  List<int> derive({
    required List<int> masterKey,
    required KeyPurpose purpose,
    int length = 32,
    List<int> salt = const <int>[],
    String context = 'cycle-platform/v1',
  }) {
    if (masterKey.length < 32) {
      throw ArgumentError.value(
        masterKey.length,
        'masterKey.length',
        'Master key must be at least 256 bits.',
      );
    }
    if (length <= 0 || length > 255 * 32) {
      throw ArgumentError.value(
        length,
        'length',
        'Invalid HKDF output length.',
      );
    }

    final effectiveSalt = salt.isEmpty ? List<int>.filled(32, 0) : salt;
    final prk = Hmac(sha256, effectiveSalt).convert(masterKey).bytes;
    final info = utf8.encode('$context/${purpose.name}');

    final output = <int>[];
    var previous = <int>[];
    var counter = 1;

    while (output.length < length) {
      final input = <int>[...previous, ...info, counter];
      previous = Hmac(sha256, prk).convert(input).bytes;
      output.addAll(previous);
      counter += 1;
    }

    return List<int>.unmodifiable(output.take(length));
  }
}
