import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:test/test.dart';

void main() {
  const deriver = KeyDeriver();
  final masterKey = List<int>.generate(32, (index) => index);

  test('same input derives the same key', () {
    final first = deriver.derive(
      masterKey: masterKey,
      purpose: KeyPurpose.database,
    );
    final second = deriver.derive(
      masterKey: masterKey,
      purpose: KeyPurpose.database,
    );

    expect(first, second);
    expect(first.length, 32);
  });

  test('different purposes derive different keys', () {
    final databaseKey = deriver.derive(
      masterKey: masterKey,
      purpose: KeyPurpose.database,
    );
    final attachmentKey = deriver.derive(
      masterKey: masterKey,
      purpose: KeyPurpose.attachment,
    );

    expect(databaseKey, isNot(attachmentKey));
  });

  test('context separation changes derived key', () {
    final first = deriver.derive(
      masterKey: masterKey,
      purpose: KeyPurpose.backup,
      context: 'cycle-platform/v1',
    );
    final second = deriver.derive(
      masterKey: masterKey,
      purpose: KeyPurpose.backup,
      context: 'cycle-platform/recovery/v1',
    );

    expect(first, isNot(second));
  });

  test('rejects undersized master key', () {
    expect(
      () => deriver.derive(
        masterKey: List<int>.filled(16, 1),
        purpose: KeyPurpose.database,
      ),
      throwsArgumentError,
    );
  });
}
