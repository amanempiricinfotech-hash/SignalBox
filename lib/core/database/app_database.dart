import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';
import '../errors/failures.dart';
import 'debug_sample_data.dart';
import 'default_categories.dart';

/// Owns the SQLite connection and the schema.
///
/// All SQL lives in the repository classes under `features/*/data`; this class
/// only opens, creates and migrates the database.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  /// Current schema version. Bump this and add a branch to [_onUpgrade] when
  /// the schema changes.
  static const int schemaVersion = 1;

  Database? _db;

  /// Opens the database on first use and reuses the handle afterwards.
  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    try {
      final opened = await _open();
      _db = opened;
      return opened;
    } on DatabaseException catch (e) {
      throw DatabaseFailure('Could not open the SignalBox database.', cause: e);
    }
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, AppConstants.databaseFileName);
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Opens an in-memory database. Used by tests.
  ///
  /// `fixtures: true` also inserts the developer fixtures from
  /// [DebugSampleData]. Most tests should insert exactly the rows they need
  /// instead.
  Future<Database> openInMemory({bool fixtures = false}) async {
    return openDatabase(
      inMemoryDatabasePath,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _onCreate(db, version);
        if (fixtures) await DebugSampleData.generate(db);
      },
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE app_sources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL UNIQUE,
        app_label TEXT NOT NULL,
        is_muted INTEGER NOT NULL DEFAULT 0,
        first_seen_at INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color_value INTEGER NOT NULL,
        is_system INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // NOTE: no secondary indexes are declared yet. Inbox queries sort on
    // posted_at and filter on package_name, so this table performs a full
    // scan on every page. See the "database query optimisation" issue.
    batch.execute('''
      CREATE TABLE notification_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL DEFAULT '',
        posted_at INTEGER NOT NULL,
        priority INTEGER NOT NULL DEFAULT 1,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        snooze_until INTEGER,
        native_key TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        match_field INTEGER NOT NULL,
        match_value TEXT NOT NULL,
        action_type INTEGER NOT NULL,
        action_value TEXT NOT NULL DEFAULT '',
        is_enabled INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await batch.commit(noResult: true);
    await DefaultCategories.insert(db);
  }

  /// Schema upgrades. Nothing to do at version 1.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Intentionally empty: v1 is the first released schema.
  }

  /// Closes the connection. Mainly useful for tests.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
