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
    });
  }

  Future<void> _initializeInternal() async {
    final databaseKey = await _keyStore.createKey(KeyPurpose.database);
    final vault = SqlCipherVaultLifecycle(
      password: base64UrlEncode(databaseKey.wrappedKey),
    );
    await vault.initialize();
    await vault.verifyIntegrity();
    _vault = vault;
    _bindRepositories(vault);
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
