import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

class SqlCipherDatabase {
  SqlCipherDatabase._(this.database);

  final Database database;

  static const int schemaVersion = 1;

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
            subject_id TEXT,
            record_id TEXT,
            actor_id TEXT,
            metadata_json TEXT,
            occurred_at TEXT NOT NULL
          )
        ''');
      },
    );

    await db.rawQuery('SELECT count(*) FROM sqlite_master');
    return SqlCipherDatabase._(db);
  }

  Future<void> close() => database.close();
}
