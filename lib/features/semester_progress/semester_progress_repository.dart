import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/data/data_providers.dart';
import '../../core/data/db/app_database.dart';
import '../../core/data/repos/local_queries.dart';
import '../../core/data/repos/marks_local.dart';
import '../../core/data/sync/outbox.dart';
import '../../core/repositories/auth_repository.dart';
import '../../core/utils/course_utils.dart';

final semesterProgressRepositoryProvider = Provider((ref) => SemesterProgressRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(outboxProvider),
    ));

/// Marks/attendance per course, from the local database. Saves are applied
/// locally at once and synced by the outbox (offline-safe).
class SemesterProgressRepository {
  final AppDatabase _db;
  final MarksLocal _marks;
  SemesterProgressRepository(this._db, Outbox outbox) : _marks = MarksLocal(_db, outbox);

  /// Current semester of the signed-in user's track (local active_semester).
  Future<String> getActiveSemesterCode() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final profile = uid == null ? null : await _db.getRow('profiles', uid);
    final track = CourseUtils.normalizeTrack('${profile?['track'] ?? profile?['semester_type'] ?? ''}');
    final row = await LocalQueries(_db).activeSemester(track) ??
        (await _db.getRows('active_semester')).firstOrNull;
    return '${row?['current_semester_code'] ?? ''}';
  }

  Future<List<Map<String, dynamic>>> getSemesterProgressData(String userId, String semesterCode) =>
      _marks.semesterRows(userId, semesterCode);

  Stream<List<Map<String, dynamic>>> watchSemesterProgressData(String userId, String semesterCode) =>
      _marks.watchSemesterRows(userId, semesterCode);

  Future<void> saveCourseMarks(String userId, String semesterCode, Map<String, dynamic> data) async {
    await _marks.save(userId, semesterCode, data,
        normalizeCode: (c) => c.toUpperCase().replaceAll(' ', ''));
  }
}

/// Re-emits whenever the semester's marks or enrollments change locally (edits, sync).
final semesterProgressDataProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, semesterCode) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(semesterProgressRepositoryProvider).watchSemesterProgressData(user.id, semesterCode);
});
