import 'dart:convert';

import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:cycle_permissions/cycle_permissions.dart';
import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 10, 10);

  test('QR pairing round-trips and rejects expired invitations', () {
    const codec = PairingQrCodec();
    final invitation = PairingInvitation(
      ownerId: 'owner-1',
      recipientId: 'partner-1',
      keyEnvelopeId: 'recipient-key-v1',
      nonce: 'nonce-1',
      expiresAt: now.add(const Duration(minutes: 5)),
    );
    final encoded = codec.encode(invitation);
    final decoded = codec.decode(encoded, now: now);
    expect(decoded.ownerId, 'owner-1');
    expect(decoded.recipientId, 'partner-1');
    expect(decoded.keyEnvelopeId, 'recipient-key-v1');
    expect(
      () => codec.decode(encoded, now: now.add(const Duration(minutes: 6))),
      throwsFormatException,
    );
  });

  test('recipient keys are independently versioned and rotated', () {
    final registry = RecipientKeyRegistry();
    final first = registry.rotate(
      ownerId: 'owner-1',
      recipientId: 'partner-1',
      newKeyEnvelopeId: 'k1',
      at: now,
    );
    final second = registry.rotate(
      ownerId: 'owner-1',
      recipientId: 'partner-1',
      newKeyEnvelopeId: 'k2',
      at: now.add(const Duration(minutes: 1)),
    );
    final other = registry.rotate(
      ownerId: 'owner-1',
      recipientId: 'partner-2',
      newKeyEnvelopeId: 'other-k1',
      at: now,
    );
    expect(first.version, 1);
    expect(second.version, 2);
    expect(other.version, 1);
    expect(
      registry
          .activeFor(ownerId: 'owner-1', recipientId: 'partner-1')!
          .keyEnvelopeId,
      'k2',
    );
  });

  test('VIEW NOTIFY and BACKUP decisions remain independent', () {
    final grant = PermissionGrant(
      id: 'g1',
      ownerId: 'owner-1',
      recipientId: 'partner-1',
      recipientKind: RecipientKind.partner,
      actions: const <PermissionAction>{
        PermissionAction.view,
        PermissionAction.backup,
      },
      scope: const PermissionScope(categories: <String>{'cycle'}),
      createdAt: now,
    );
    final decision = const SharePolicy().evaluate(
      ownerId: 'owner-1',
      recipientId: 'partner-1',
      category: 'cycle',
      at: now,
      grants: <PermissionGrant>[grant],
    );
    expect(decision.canView, isTrue);
    expect(decision.canNotify, isFalse);
    expect(decision.canBackup, isTrue);
  });

  test('relay envelope is opaque and recipient-bound', () async {
    final transport = SharingTransport(_FakeCipher());
    final envelope = await transport.encryptForRecipient(
      messageId: 'm1',
      ownerId: 'owner-1',
      recipientId: 'partner-1',
      keyEnvelopeId: 'k1',
      plaintext: utf8.encode('sensitive-record'),
      createdAt: now,
    );
    final relayJson = jsonEncode(envelope.toOpaqueMap());
    expect(relayJson, isNot(contains('sensitive-record')));
    expect(
      await transport.decryptForRecipient(
        envelope: envelope,
        recipientId: 'partner-1',
      ),
      orderedEquals(utf8.encode('sensitive-record')),
    );
    expect(
      () => transport.decryptForRecipient(
        envelope: envelope,
        recipientId: 'partner-2',
      ),
      throwsStateError,
    );
  });

  test('blind backup uses an opaque backup envelope', () async {
    final transport = SharingTransport(_FakeCipher());
    final vault = utf8.encode('CYCLEVAULT-encrypted-content');
    final envelope = await transport.encryptBlindBackup(
      backupId: 'backup-1',
      ownerId: 'owner-1',
      recipientId: 'partner-1',
      keyEnvelopeId: 'backup-k1',
      cycleVaultBytes: vault,
      createdAt: now,
    );
    expect(envelope.kind, 'blind-backup');
    expect(jsonEncode(envelope.toOpaqueMap()), isNot(contains('CYCLEVAULT')));
  });

  test('private notification modes never leak detail while locked', () {
    const presenter = NotificationPrivacyPresenter();
    final locked = presenter.present(
      mode: NotificationPrivacyMode.detailedWhenUnlocked,
      category: 'cycle',
      detail: 'Sensitive detail',
      deviceUnlocked: false,
    );
    expect(locked.redacted, isTrue);
    expect(locked.body, isNot(contains('Sensitive detail')));
    final unlocked = presenter.present(
      mode: NotificationPrivacyMode.detailedWhenUnlocked,
      category: 'cycle',
      detail: 'Sensitive detail',
      deviceUnlocked: true,
    );
    expect(unlocked.redacted, isFalse);
    expect(unlocked.body, 'Sensitive detail');
  });

  test('revocation rotates recipient key and stops notifications', () async {
    final grant = PermissionGrant(
      id: 'g1',
      ownerId: 'owner-1',
      recipientId: 'partner-1',
      recipientKind: RecipientKind.partner,
      actions: const <PermissionAction>{
        PermissionAction.view,
        PermissionAction.notify,
      },
      scope: const PermissionScope(categories: <String>{'cycle'}),
      createdAt: now,
    );
    final result = await const SharingRevocationCoordinator().revoke(
      grant: grant,
      keyRotator: _FakeRotator(),
      at: now,
    );
    expect(result.newKeyEnvelopeId, 'rotated-owner-1-partner-1');
    expect(result.notificationsStopped, isTrue);
  });

  test('sync conflicts resolve deterministically', () {
    final left = SyncVersionedValue<String>(
      value: 'left',
      revision: 3,
      modifiedAt: now,
      deviceId: 'device-b',
    );
    final right = SyncVersionedValue<String>(
      value: 'right',
      revision: 3,
      modifiedAt: now,
      deviceId: 'device-a',
    );
    final resolved = const SyncConflictResolver().resolve(left, right);
    expect(resolved.value, 'right');
  });
}

class _FakeCipher implements AuthenticatedCipher {
  final Map<String, List<int>> _plaintext = <String, List<int>>{};

  @override
  Future<CiphertextEnvelope> encrypt({
    required List<int> plaintext,
    required String keyEnvelopeId,
    List<int>? associatedData,
  }) async {
    final ciphertext = plaintext.map((value) => value ^ 0x5a).toList();
    _plaintext[keyEnvelopeId] = List<int>.of(plaintext);
    return CiphertextEnvelope(
      algorithm: 'TEST-ONLY',
      keyEnvelopeId: keyEnvelopeId,
      nonce: const <int>[1, 2, 3],
      ciphertext: ciphertext,
      authenticationTag: const <int>[4, 5, 6],
      associatedData: associatedData,
    );
  }

  @override
  Future<List<int>> decrypt(CiphertextEnvelope envelope) async =>
      List<int>.of(_plaintext[envelope.keyEnvelopeId]!);
}

class _FakeRotator implements RecipientKeyRotator {
  @override
  Future<String> rotate({
    required String ownerId,
    required String recipientId,
    required DateTime at,
  }) async =>
      'rotated-$ownerId-$recipientId';
}
