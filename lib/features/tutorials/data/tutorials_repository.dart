import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/data_providers.dart';
import '../../../core/data/db/app_database.dart';
import 'tutorial_model.dart';

final tutorialsRepositoryProvider = Provider<TutorialsRepository>(
  (ref) => TutorialsRepository(ref.watch(appDatabaseProvider)),
);

/// Tutorials from the local database (scope `reference`); network only before the first sync.
class TutorialsRepository {
  final AppDatabase _db;
  TutorialsRepository(this._db);

  Future<List<Tutorial>> fetchAll() async {
    var rows = (await _db.getRows('tutorials')).where((r) => r['is_active'] == true).toList();
    if (rows.isEmpty) {
      final data = await Supabase.instance.client
          .from('tutorials')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);
      rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    rows.sort((a, b) => ((a['display_order'] as num?) ?? 0).compareTo((b['display_order'] as num?) ?? 0));
    return rows.map(Tutorial.fromMap).toList();
  }
}
