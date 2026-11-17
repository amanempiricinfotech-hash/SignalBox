import 'package:sqflite/sqflite.dart';

/// The categories SignalBox ships with.
///
/// These are application defaults, not sample data: the categorisation feature
/// needs buckets to exist before a notification can be filed. They are created
/// once, when the database is first created, and are marked as system
/// categories so they cannot be deleted.
class DefaultCategories {
  const DefaultCategories._();

  /// (name, ARGB colour)
  static const List<(String, int)> values = <(String, int)>[
    ('Messages', 0xFF3E63DD),
    ('Social', 0xFF8E4EC6),
    ('Finance', 0xFF2E9E5B),
    ('Promotions', 0xFFE5A32A),
    ('System', 0xFF8B8D98),
  ];

  static Future<void> insert(Database db) async {
    final batch = db.batch();
    for (final category in values) {
      batch.insert('categories', {
        'name': category.$1,
        'color_value': category.$2,
        'is_system': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }
}
