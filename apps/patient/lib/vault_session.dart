import 'dart:convert';

import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:cycle_secure_key_store/cycle_secure_key_store.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:cycle_storage_sqlcipher/cycle_storage_sqlcipher.dart';

class PatientVaultSession {
  PatientVaultSession({FlutterSecureKeyStore? keyStore})
      : _keyStore = keyStore ?? FlutterSecureKeyStore();

  final FlutterSecureKeyStore _keyStore;

  SqlCipherVaultLifecycle? _vault;
  HealthEventRepository? _repository;
  AuditLogRepository? _auditLog;

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

  Future<VaultState> state() async {
    final vault = _vault;
    if (vault == null) return VaultState.uninitialized;
    return vault.state();
  }

  Future<void> initialize() async {
    final databaseKey = await _keyStore.createKey(KeyPurpose.database);
    final vault = SqlCipherVaultLifecycle(
      password: base64UrlEncode(databaseKey.wrappedKey),
    );
    await vault.initialize();
    await vault.verifyIntegrity();
    _vault = vault;
    _bindRepositories(vault);
  }

  Future<void> lock() async {
    final vault = _vault;
    _repository = null;
    _auditLog = null;
    if (vault != null) {
      await vault.lock();
    }
  }

  Future<void> unlock() async {
    final vault = _vault;
    if (vault == null) {
      await initialize();
      return;
    }
    await vault.unlock();
    await vault.verifyIntegrity();
    _bindRepositories(vault);
  }

  void _bindRepositories(SqlCipherVaultLifecycle vault) {
    _repository = SqlCipherHealthEventRepository(vault.database);
    _auditLog = SqlCipherAuditLogRepository(vault.database);
  }
}
