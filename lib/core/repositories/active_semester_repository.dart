import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/data_providers.dart';
import '../data/db/app_database.dart';
import '../data/repos/local_queries.dart';
import '../providers/supabase_provider.dart';
import '../utils/course_utils.dart';

part 'active_semester_repository.g.dart';

/// Active semester / semester list from the local database (scope `meta`,
/// pulled whenever the admin changes it). Network only before the first sync.
class ActiveSemesterRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;

  ActiveSemesterRepository(this._supabase, this._db);

  Future<Map<String, dynamic>> getActiveSemester(String track, {bool forceRefresh = false}) async {
    final normalizedTrack = CourseUtils.normalizeTrack(track);
    final local = await LocalQueries(_db).activeSemester(normalizedTrack);
    if (local != null) return local;
    return await _supabase.from('active_semester').select().eq('track', normalizedTrack).limit(1).single();
  }

  Future<List<Map<String, dynamic>>> getAllSemesters({bool forceRefresh = false}) async {
    final local = await _db.getRows('semesters');
    if (local.isNotEmpty) {
      local.sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
      return local;
    }
    final response = await _supabase.from('semesters').select('title').order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}

@riverpod
ActiveSemesterRepository activeSemesterRepository(Ref ref) {
  return ActiveSemesterRepository(ref.watch(supabaseClientProvider), ref.watch(appDatabaseProvider));
}
