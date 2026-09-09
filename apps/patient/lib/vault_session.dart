import 'dart:convert';

import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:cycle_secure_key_store/cycle_secure_key_store.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:cycle_storage_file_vault/cycle_storage_file_vault.dart';
import 'package:cycle_storage_sqlcipher/cycle_storage_sqlcipher.dart';
import 'package:path_provider/path_provider.dart';

class PatientVaultSession {
  PatientVaultSession({FlutterSecureKeyStore? keyStore})
    : _keyStore = keyStore ?? FlutterSecureKeyStore();

  final FlutterSecureKeyStore _keyStore;
  final KeyDeriver _keyDeriver = const KeyDeriver();

  SqlCipherVaultLifecycle? _vault;
  HealthEventRepository? _repository;
  AuditLogRepository? _auditLog;
  AttachmentVault? _attachmentVault;
  RawSensorVault? _rawSensorVault;
  Future<void> _operation = Future<void>.value();

  HealthEventRepository get repository {
    final value = _repository;
    if (value == null) {
      throw StateError('Vault session is locked.');
    }
    return value;
  }

  AuditLogRepository get auditLog {
    final value = _auditLog;
    if (value == null) {
      throw StateError('Vault session is locked.');
    }
    return value;
  }

  AttachmentVault get attachmentVault {
    final value = _attachmentVault;
    if (value == null) {
      throw StateError('Attachment vault is locked.');
    }
    return value;
  }

  RawSensorVault get rawSensorVault {
    final value = _rawSensorVault;
    if (value == null) {
      throw StateError('Raw sensor vault is locked.');
    }
    return value;
  }

  Future<VaultState> state() async {
    final vault = _vault;
    if (vault == null) return VaultState.uninitialized;
    return vault.state();
  }

  Future<void> initialize() {
    return _serialize(_initializeInternal);
  }

  Future<void> lock() {
    return _serialize(() async {
      final vault = _vault;
      _repository = null;
      _auditLog = null;
      _attachmentVault = null;
      _rawSensorVault = null;
      if (vault != null) {
        await vault.lock();
      }
    });
  }

  Future<void> unlock() {
    return _serialize(() async {
      final vault = _vault;
      if (vault == null) {
        await _initializeInternal();
        return;
      }
      await vault.unlock();
      await vault.verifyIntegrity();
      _bindRepositories(vault);
      await _bindBinaryVaults();
    });
  }

  Future<void> _initializeInternal() async {
    final master = await _keyStore.createKey(KeyPurpose.master);
    final databaseKey = _keyDeriver.derive(
      masterKey: master.wrappedKey,
      purpose: KeyPurpose.database,
      context: 'cycle-platform/patient/v1',
    );
    final vault = SqlCipherVaultLifecycle(
      password: base64UrlEncode(databaseKey),
    );
    await vault.initialize();
    await vault.verifyIntegrity();
    _vault = vault;
    _bindRepositories(vault);
    await _bindBinaryVaults(master: master);
  }

  Future<void> _bindBinaryVaults({KeyEnvelope? master}) async {
    final activeMaster = master ?? await _keyStore.createKey(KeyPurpose.master);
    final attachmentKey = _keyDeriver.derive(
      masterKey: activeMaster.wrappedKey,
      purpose: KeyPurpose.attachment,
      context: 'cycle-platform/patient/v1',
    );
    final sensorKey = _keyDeriver.derive(
      masterKey: activeMaster.wrappedKey,
      purpose: KeyPurpose.sensorVault,
      context: 'cycle-platform/patient/v1',
    );
    final attachmentKeyId =
        'derived:${activeMaster.id}:attachment:${activeMaster.version}';
    final sensorKeyId =
        'derived:${activeMaster.id}:sensorVault:${activeMaster.version}';
    final attachmentCipher = AesGcmAuthenticatedCipher(
      keyResolver: (keyEnvelopeId) async {
        if (keyEnvelopeId != attachmentKeyId) {
          throw StateError('Unknown attachment key envelope.');
        }
        return attachmentKey;
      },
    );
    final sensorCipher = AesGcmAuthenticatedCipher(
      keyResolver: (keyEnvelopeId) async {
        if (keyEnvelopeId != sensorKeyId) {
          throw StateError('Unknown sensor key envelope.');
        }
        return sensorKey;
      },
    );
    final supportDirectory = await getApplicationSupportDirectory();

    _attachmentVault = EncryptedAttachmentVault(
      directory: supportDirectory.createTempSync('cycle-attachments-'),
      cipher: attachmentCipher,
      keyEnvelopeId: attachmentKeyId,
    );
    _rawSensorVault = EncryptedRawSensorVault(
      directory: supportDirectory.createTempSync('cycle-sensors-'),
      cipher: sensorCipher,
      keyEnvelopeId: sensorKeyId,
    );
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _operation.then((_) => action(), onError: (_) => action());
    _operation = next;
    return next;
  }

  void _bindRepositories(SqlCipherVaultLifecycle vault) {
    _repository = SqlCipherHealthEventRepository(vault.database);
    _auditLog = SqlCipherAuditLogRepository(vault.database);
  }
}
