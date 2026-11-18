import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/data_providers.dart';
import '../../core/data/repos/local_writer.dart';
import '../../core/data/sync/scope_catalog.dart';
import '../../core/models/profile.dart';
import '../../core/utils/course_utils.dart';

/// The signed-in user's profile, from the local database (offline-first).
/// Emits null while signed out, and also before the very first sync of a new
/// device — use [userDataReadyProvider] to tell "not downloaded yet" from "no profile".
final profileProvider = StreamProvider<Profile?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(appDatabaseProvider).watchRow('profiles', uid).map((j) {
    if (j == null) return null;
    try {
      return Profile.fromJson(j);
    } catch (e) {
      if (kDebugMode) debugPrint('[profileProvider] bad local profile row: $e');
      return null;
    }
  });
});

/// True once the user's own data has been downloaded at least once on this
/// device (or imported from the previous app version's cache).
final userDataReadyProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(false);
  final db = ref.watch(appDatabaseProvider);
  final scope = ScopeCatalog.userScope(uid);
  return (db.select(db.syncScopes)..where((t) => t.scope.equals(scope)))
      .watchSingleOrNull()
      .map((s) => s?.cursor != null);
});

final authStateProvider = StreamProvider<AuthState>((ref) async* {
  final client = Supabase.instance.client;
  yield AuthState(AuthChangeEvent.initialSession, client.auth.currentSession);
  yield* client.auth.onAuthStateChange;
});

/// Must the student submit grades before using the app? Computed from local
/// enrollments + active semester, so it is instant and works offline.
final requiresGradeEntryProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return false;

  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return false;
  final semesters = await ref.watch(localRowsProvider(('active_semester', null)).future);
  final enrollments = await ref.watch(localRowsProvider(('enrollments', null)).future);

  return computeRequiresGradeEntry(
    track: CourseUtils.normalizeTrack(profile.track ?? profile.semesterType),
    activeSemesters: semesters,
    enrollments: enrollments,
    now: DateTime.now(),
  );
});

/// Same rule as the previous online check, on local rows. Semester codes are
/// compared in canonical form ("Fall 2026" == "fall2026").
@visibleForTesting
bool computeRequiresGradeEntry({
  required String track,
  required List<Map<String, dynamic>> activeSemesters,
  required List<Map<String, dynamic>> enrollments,
  required DateTime now,
}) {
  final active = activeSemesters.where((r) => r['track'] == track).firstOrNull;
  if (active == null) return false;
  final activeCode = normSemester(active['current_semester_code'] as String?);

  final unsubmitted = enrollments.where((e) => e['status'] == 'enrolled' && e['grade'] == null).toList();
  if (unsubmitted.any((e) => normSemester(e['semester_code'] as String?) != activeCode)) return true;

  final start = DateTime.tryParse('${active['grade_submission_start']}');
  if (start != null && now.isAfter(start.add(const Duration(days: 1)))) {
    return unsubmitted.any((e) => normSemester(e['semester_code'] as String?) == activeCode);
  }
  return false;
}
