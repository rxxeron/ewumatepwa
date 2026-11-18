import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/semester_course_marks.dart';
import '../models/semester_summary.dart';
import '../providers/supabase_provider.dart';
import '../data/data_providers.dart';
import '../data/db/app_database.dart';
import '../data/repos/marks_local.dart';
import '../data/sync/outbox.dart';
import 'auth_repository.dart';

import 'package:ewumate/core/providers/academic_providers.dart';
import 'package:ewumate/core/utils/course_utils.dart';

part 'progress_repository.g.dart';

/// Course marks and semester summaries from the local database. Shares
/// [MarksLocal] with SemesterProgressRepository, so both screens see the same
/// rows and neither can overwrite the other's fields (e.g. attendance in marks_data).
class ProgressRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;
  final MarksLocal _marks;

  ProgressRepository(this._supabase, this._db, Outbox outbox) : _marks = MarksLocal(_db, outbox);

  static List<SemesterCourseMarks> _parseMarks(List<Map<String, dynamic>> rows) {
    final out = <SemesterCourseMarks>[];
    for (final r in rows) {
      try {
        out.add(SemesterCourseMarks.fromJson(r));
      } catch (e) {
        if (kDebugMode) debugPrint('[ProgressRepo] bad marks row ${r['id']}: $e');
      }
    }
    return out;
  }

  Future<List<SemesterCourseMarks>> getCourseMarks(String userId, String semesterCode) async =>
      _parseMarks(await _marks.semesterRows(userId, semesterCode));

  Stream<List<SemesterCourseMarks>> watchCourseMarks(String userId, String semesterCode) =>
      _marks.watchSemesterRows(userId, semesterCode).map(_parseMarks);

  /// Sends only the model's columns; server-side columns the model lacks
  /// (marks_data) are left untouched by the upsert.
  Future<void> updateCourseMarks(SemesterCourseMarks marks) async {
    await _marks.save(marks.userId, marks.semesterCode, marks.toJson());
  }

  static List<SemesterSummary> _parseSummaries(List<Map<String, dynamic>> rows, String userId) {
    final out = <SemesterSummary>[];
    for (final r in rows.where((r) => r['user_id'] == userId)) {
      try {
        out.add(SemesterSummary.fromJson(r));
      } catch (_) {}
    }
    out.sort((a, b) => b.semesterCode.compareTo(a.semesterCode));
    return out;
  }

  Future<List<SemesterSummary>> getSemesterSummaries(String userId) async =>
      _parseSummaries(await _db.getRows('semester_summaries'), userId);

  Stream<List<SemesterSummary>> watchSemesterSummaries(String userId) =>
      _db.watchRows('semester_summaries').map((rows) => _parseSummaries(rows, userId));

  Future<List<SemesterSummary>> getSemesterSummariesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final summaryMap = <String, SemesterSummary>{};
    for (final r in await _db.getRows('semester_summaries')) {
      if (!ids.contains(r['id'])) continue;
      try {
        summaryMap[r['id'] as String] = SemesterSummary.fromJson(r);
      } catch (_) {}
    }
    return ids.where(summaryMap.containsKey).map((id) => summaryMap[id]!).toList();
  }

  Future<Map<String, dynamic>?> getProgramDetails(String programCode) async {
    final local = (await _db.getRows('programs'))
        .where((r) => '${r['program_code']}'.toUpperCase() == programCode.toUpperCase())
        .firstOrNull;
    if (local != null) return local;
    try {
      // Before the first sync (new device): ask the server once.
      return await _supabase.from('programs').select().eq('program_code', programCode).maybeSingle();
    } catch (_) {
      return null;
    }
  }
}

@riverpod
ProgressRepository progressRepository(Ref ref) {
  return ProgressRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(outboxProvider),
  );
}

@riverpod
Stream<List<SemesterCourseMarks>> currentSemesterMarks(Ref ref) async* {
  final user = ref.watch(currentUserProvider);
  final semCode = await ref.watch(currentSemesterCodeProvider.future);
  if (user == null || semCode == null) {
    yield [];
    return;
  }
  yield* ref
      .watch(progressRepositoryProvider)
      .watchCourseMarks(user.id, CourseUtils.cleanSemester(semCode))
      .map((list) => list.where((m) => m.courseCode.length <= 15).toList());
}

@riverpod
Stream<List<SemesterSummary>> allSemesterSummaries(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(progressRepositoryProvider).watchSemesterSummaries(user.id);
}
