import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

class SqlCipherDatabase {
  SqlCipherDatabase._(this.database);

  final Database database;

  static const int schemaVersion = 4;

  static Future<SqlCipherDatabase> openDefault({
    String fileName = 'cycle.db',
    required String password,
  }) async {
    final directory = await getDatabasesPath();
    return open(directory: directory, fileName: fileName, password: password);
  }

  static Future<SqlCipherDatabase> open({
    required String directory,
    required String fileName,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'must not be empty');
    }

    final path = p.join(directory, fileName);
    final db = await openDatabase(
      path,
      password: password,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA secure_delete = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE audit_events ADD COLUMN subject_type TEXT NOT NULL DEFAULT 'unknown'",
          );
        }
        if (oldVersion < 3) {
          await _createHealthSyncCursorSchema(db);
        }
        if (oldVersion < 4) {
          await _createHealthImportHistorySchema(db);
        }
      },
    );

    await db.rawQuery('SELECT count(*) FROM sqlite_master');
    return SqlCipherDatabase._(db);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE health_events (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        episode_id TEXT,
        payload_json TEXT NOT NULL,
        observed_at TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        schema_version INTEGER NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_health_events_subject_observed '
      'ON health_events(subject_id, observed_at)',
    );
    await db.execute('''
      CREATE TABLE audit_events (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        subject_type TEXT NOT NULL,
        actor_id TEXT NOT NULL,
        metadata_json TEXT,
        occurred_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_audit_events_subject_occurred '
      'ON audit_events(subject_id, occurred_at)',
    );
    await _createHealthSyncCursorSchema(db);
    await _createHealthImportHistorySchema(db);
  }

  static Future<void> _createHealthSyncCursorSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_sync_cursors (
        subject_id TEXT NOT NULL,
        source TEXT NOT NULL,
        cursor_value TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(subject_id, source)
      )
    ''');
  }

  static Future<void> _createHealthImportHistorySchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_import_history (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        source TEXT NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT NOT NULL,
        imported INTEGER NOT NULL,
        skipped_permission INTEGER NOT NULL,
        skipped_duplicate INTEGER NOT NULL,
        unmapped INTEGER NOT NULL,
        deleted INTEGER NOT NULL,
        used_full_refresh INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_health_import_history_subject_finished '
      'ON health_import_history(subject_id, finished_at DESC)',
    );
  }

  Future<void> close() => database.close();
}
