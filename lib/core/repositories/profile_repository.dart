import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/data_providers.dart';
import '../data/db/app_database.dart';
import '../data/repos/local_queries.dart';
import '../data/repos/local_writer.dart';
import '../data/repos/weekly_grid.dart';
import '../data/sync/outbox.dart';
import '../data/sync/scope_catalog.dart';
import '../models/profile.dart';
import '../providers/supabase_provider.dart';
import '../utils/course_utils.dart';

part 'profile_repository.g.dart';

/// Profile + enrollment changes. Reads are local; writes are applied locally at
/// once and queued (enroll/drop/switch as one atomic server call each), so they
/// work offline. A server rejection rolls every local part back together.
class ProfileRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;
  final Outbox _outbox;

  ProfileRepository(this._supabase, this._db, this._outbox);

  LocalWriter _writer(String userId) => LocalWriter(_db, _outbox, userId);

  /// Columns the server computes (triggers/RPCs). Never sent from a queued
  /// profile edit, so an offline edit cannot overwrite newer server values.
  static const _serverManaged = {
    'cgpa', 'total_credits_earned', 'enrolled_sections', 'enrolled_sections_next', 'enrolled_credits',
    'enrolled_credits_next', 'total_courses_completed', 'past_history', 'last_active_at', 'app_open_count',
    'app_version', 'updated_at', 'created_at', 'track', 'semester_type', 'sync_xid',
  };

  static Profile? _parse(Map<String, dynamic>? j) {
    if (j == null) return null;
    try {
      return Profile.fromJson(j);
    } catch (e) {
      if (kDebugMode) debugPrint('[ProfileRepository] bad profile row: $e');
      return null;
    }
  }

  Future<Profile?> getProfile(String userId, {bool forceRefresh = true}) async {
    final local = _parse(await _db.getRow('profiles', userId));
    if (local != null) return local;
    // Nothing synced yet on this device (first sign-in): one direct read.
    try {
      final data = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
      if (data == null) return null;
      await _db.putRow(tbl: 'profiles', rowId: userId, scope: ScopeCatalog.userScope(userId), data: data);
      return _parse(data);
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  Future<void> updateProfile(Profile profile) async {
    final sanitizedName = profile.fullName
            ?.trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : '')
            .join(' ') ??
        '';
    final row = profile.copyWith(fullName: sanitizedName).toJson()
      ..removeWhere((k, _) => _serverManaged.contains(k));
    await _writer(profile.id).upsert('profiles', row, label: 'Profile update');
  }

  // ---------------------------------------------------------------------------
  // Enrollment
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _myEnrollments(String userId, String sem) async =>
      (await _db.getRows('enrollments', semester: sem)).where((e) => e['user_id'] == userId).toList();

  /// Optimistic changes to the profile's section arrays and the weekly grid,
  /// recomputed locally from [enrollmentsAfter] (same rules as the server).
  Future<List<LocalChange>> _derivedChanges(
    String userId,
    String sem,
    List<Map<String, dynamic>> enrollmentsAfter,
  ) async {
    final changes = <LocalChange>[];
    final profile = await _db.getRow('profiles', userId);
    final track = CourseUtils.normalizeTrack('${profile?['track'] ?? profile?['semester_type'] ?? ''}');
    final active = await LocalQueries(_db).activeSemester(track);
    final currentRaw = '${active?['current_semester_code'] ?? ''}';
    final isCurrent = normSemester(currentRaw) == sem;
    final isNext = normSemester('${active?['next_semester_code'] ?? ''}') == sem;
    final sectionIds = enrollmentsAfter.map((e) => '${e['section_id']}').where((s) => s != 'null').toList();

    if (profile != null && (isCurrent || isNext)) {
      changes.add(LocalChange('profiles', userId, {
        ...profile,
        isCurrent ? 'enrolled_sections' : 'enrolled_sections_next': sectionIds,
      }));
    }

    if (isCurrent) {
      final states = (await _db.getRows('user_semester_states', semester: sem)).where((r) => r['user_id'] == userId);
      final existing = states.firstOrNull;
      final semCode = '${existing?['semester_code'] ?? currentRaw}';
      final sections = <Map<String, dynamic>>[];
      for (final id in sectionIds) {
        final s = await _db.getRow('courses_$sem', id);
        if (s != null) sections.add(s);
      }
      changes.add(LocalChange('user_semester_states', '$userId|$semCode', {
        ...?existing,
        'user_id': userId,
        'semester_code': semCode,
        'weekly_grid_cache': buildWeeklyGrid(sections, programCode: profile?['program_code'] as String?),
      }));
    }
    return changes;
  }

  Future<void> enrollCourseSection({
    required String userId,
    required String courseCode,
    required String semesterCode,
    required String sectionId,
    required String sectionNumber,
    required List<String> currentSections,
  }) async {
    final sem = normSemester(semesterCode);
    final section = await _db.getRow('courses_$sem', sectionId);
    final mine = await _myEnrollments(userId, sem);
    final existing = mine.where((e) => CourseUtils.areEquivalent('${e['course_code']}', courseCode)).firstOrNull;
    final id = '${existing?['id'] ?? const Uuid().v4()}';

    final row = <String, dynamic>{
      ...?existing,
      'id': id,
      'user_id': userId,
      'course_code': existing?['course_code'] ?? section?['course_code'] ?? courseCode,
      'semester_code': sem,
      'section_id': sectionId,
      'section': sectionNumber,
      'status': 'enrolled',
      '_pending': true,
    };
    final after = [...mine.where((e) => e['id'] != id), row];

    await _writer(userId).rpc(
      'v2_enroll_section',
      {
        'p_semester': semesterCode,
        'p_course_code': courseCode,
        'p_section_id': sectionId,
        'p_expected_schedule': section?['schedule_data'],
        'p_client_id': existing == null ? id : null,
      },
      changes: [LocalChange('enrollments', id, row), ...await _derivedChanges(userId, sem, after)],
      label: 'Enroll in $courseCode (section $sectionNumber)',
    );
  }

  Future<void> dropCourseSection({
    required String userId,
    required String sectionId,
    required String semesterCode,
    required List<String> currentSections,
  }) async {
    final sem = normSemester(semesterCode);
    final mine = await _myEnrollments(userId, sem);
    final dropped = mine.where((e) => e['section_id'] == sectionId).toList();
    final after = mine.where((e) => e['section_id'] != sectionId).toList();

    await _writer(userId).rpc(
      'v2_drop_section',
      {'p_semester': semesterCode, 'p_section_id': sectionId},
      changes: [
        for (final e in dropped) LocalChange('enrollments', '${e['id']}', null),
        ...await _derivedChanges(userId, sem, after),
      ],
      label: 'Drop ${dropped.firstOrNull?['course_code'] ?? 'course'}',
    );
  }

  Future<void> switchCourseSection({
    required String userId,
    required String courseCode,
    required String semesterCode,
    required String oldSectionId,
    required String newSectionId,
    required String newSectionNumber,
    required List<String> currentSections,
  }) async {
    final sem = normSemester(semesterCode);
    final section = await _db.getRow('courses_$sem', newSectionId);
    final mine = await _myEnrollments(userId, sem);
    final existing = mine
        .where((e) => e['section_id'] == oldSectionId || CourseUtils.areEquivalent('${e['course_code']}', courseCode))
        .firstOrNull;
    final id = '${existing?['id'] ?? const Uuid().v4()}';
    final row = <String, dynamic>{
      ...?existing,
      'id': id,
      'user_id': userId,
      'course_code': existing?['course_code'] ?? courseCode,
      'semester_code': existing?['semester_code'] ?? sem,
      'section_id': newSectionId,
      'section': newSectionNumber,
      'status': 'enrolled',
      '_pending': true,
    };
    final after = [...mine.where((e) => e['id'] != id), row];

    await _writer(userId).rpc(
      'v2_switch_section',
      {
        'p_semester': semesterCode,
        'p_course_code': courseCode,
        'p_old_section_id': oldSectionId,
        'p_new_section_id': newSectionId,
        'p_expected_schedule': section?['schedule_data'],
      },
      changes: [LocalChange('enrollments', id, row), ...await _derivedChanges(userId, sem, after)],
      label: 'Switch $courseCode to section $newSectionNumber',
    );
  }

  Stream<Profile?> streamProfile(String userId) => _db.watchRow('profiles', userId).map(_parse);

  /// Once per app run (SessionGuardian). Online only; skipped silently offline.
  Future<void> recordActivity(String userId) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await _supabase.rpc('record_app_open', params: {
        'p_user_id': userId,
        'p_app_version': packageInfo.version,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to record activity: $e');
    }
  }
}

@riverpod
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(outboxProvider),
  );
}

@Riverpod(keepAlive: true)
Stream<Profile?> userProfile(Ref ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).streamProfile(uid);
}
