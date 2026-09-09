import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:cycle_secure_key_store/cycle_secure_key_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('Android secure storage uses the Cycle namespace', () {
    const options = FlutterSecureKeyStore.androidOptions;

    expect(options.storageNamespace, 'cycle.secure_keys');
  });

  test('iOS policy keeps keys device-bound while unlocked', () {
    const options = FlutterSecureKeyStore.iosOptions;

    expect(options.accessibility, KeychainAccessibility.unlocked_this_device);
    expect(options.synchronizable, isFalse);
  });

  test('createKey is idempotent for an active purpose', () async {
    final store = FlutterSecureKeyStore(storage: const FlutterSecureStorage());

    final first = await store.createKey(KeyPurpose.master);
    final second = await store.createKey(KeyPurpose.master);

    expect(second.id, first.id);
    expect(second.version, 1);
    expect(second.wrappedKey, first.wrappedKey);
  });

  test(
    'rotateKey replaces the active envelope and increments version',
    () async {
      final store = FlutterSecureKeyStore(
        storage: const FlutterSecureStorage(),
      );

      final first = await store.createKey(KeyPurpose.master);
      final rotated = await store.rotateKey(KeyPurpose.master);
      final active = await store.getActiveKey(KeyPurpose.master);

      expect(rotated.version, 2);
      expect(rotated.rotatedFromEnvelopeId, first.id);
      expect(active?.id, rotated.id);
      expect(active?.wrappedKey, rotated.wrappedKey);
    },
  );

  test('revokeKey removes the active envelope', () async {
    final store = FlutterSecureKeyStore(storage: const FlutterSecureStorage());

    final key = await store.createKey(KeyPurpose.attachment);
    await store.revokeKey(key.id);

    expect(await store.getActiveKey(KeyPurpose.attachment), isNull);
  });

  test('destroyAllKeys clears every Cycle key namespace', () async {
    final store = FlutterSecureKeyStore(storage: const FlutterSecureStorage());

    await store.createKey(KeyPurpose.master);
    await store.createKey(KeyPurpose.notification);
    await store.destroyAllKeys();

    expect(await store.getActiveKey(KeyPurpose.master), isNull);
    expect(await store.getActiveKey(KeyPurpose.notification), isNull);
  });
}
