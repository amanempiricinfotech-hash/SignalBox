import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';
import 'core/services/preferences_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the database and load preferences before the first frame so that the
  // rest of the app can depend on them synchronously.
  //
  // Nothing is written here. SignalBox starts empty and fills up with the
  // user's own notifications once they grant notification access.
  final database = await AppDatabase.instance.database;
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const SignalBoxApp(),
    ),
  );
}
