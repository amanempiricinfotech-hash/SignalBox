import 'package:signalbox/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Points sqflite at the FFI implementation so tests can run on the host.
///
/// Call this once from `setUpAll` in every test that touches the database.
///
/// The no-isolate factory is deliberate: `flutter_test` runs widget tests on a
/// fake async clock, and the default isolate-backed factory never completes its
/// work under that clock, which makes `pumpAndSettle` time out. Running SQLite
/// in the test isolate keeps widget tests and unit tests on the same setup.
void initTestDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
}

/// A fresh in-memory database with the production schema.
///
/// Pass `fixtures: true` to also insert the developer fixtures. Prefer
/// inserting exactly the rows a test needs: it reads better in review and does
/// not break when the fixtures change.
Future<Database> openTestDatabase({bool fixtures = false}) {
  return AppDatabase.instance.openInMemory(fixtures: fixtures);
}
