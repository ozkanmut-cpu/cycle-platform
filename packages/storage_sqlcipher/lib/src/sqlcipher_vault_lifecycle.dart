import 'package:cycle_storage/cycle_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'sqlcipher_database.dart';

class SqlCipherVaultLifecycle implements VaultLifecycle {
  SqlCipherVaultLifecycle({required this.password, this.fileName = 'cycle.db'});

  final String password;
  final String fileName;

  VaultState _state = VaultState.uninitialized;
  SqlCipherDatabase? _database;

  SqlCipherDatabase get database {
    final value = _database;
    if (value == null || _state != VaultState.unlocked) {
      throw StateError('Vault is not unlocked.');
    }
    return value;
  }

  @override
  Future<VaultState> state() async => _state;

  @override
  Future<void> initialize() async {
    if (_state == VaultState.erased) {
      _state = VaultState.uninitialized;
    }
    await unlock();
  }

  @override
  Future<void> unlock() async {
    if (_state == VaultState.unlocked && _database != null) return;

    try {
      _database = await SqlCipherDatabase.openDefault(
        fileName: fileName,
        password: password,
      );
      _state = VaultState.unlocked;
    } catch (_) {
      _database = null;
      _state = VaultState.corrupted;
      rethrow;
    }
  }

  @override
  Future<void> lock() async {
    final value = _database;
    _database = null;
    if (value != null) {
      await value.close();
    }
    if (_state != VaultState.erased) {
      _state = VaultState.locked;
    }
  }

  @override
  Future<void> verifyIntegrity() async {
    final rows = await database.database.rawQuery('PRAGMA integrity_check');
    final result = rows.isEmpty ? null : rows.first.values.first?.toString();
    if (result?.toLowerCase() != 'ok') {
      _state = VaultState.corrupted;
      throw StateError('Encrypted vault integrity check failed: $result');
    }
  }

  @override
  Future<void> erase() async {
    await lock();
    final directory = await getDatabasesPath();
    final path = p.join(directory, fileName);
    await deleteDatabase(path);
    _state = VaultState.erased;
  }
}
