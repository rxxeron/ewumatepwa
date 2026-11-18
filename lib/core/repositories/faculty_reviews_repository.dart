import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/faculty_review.dart';
import '../providers/supabase_provider.dart';
import '../data/data_providers.dart';
import '../data/db/app_database.dart';
import '../data/sync/sync_signals.dart';

final facultyReviewsRepositoryProvider = Provider<FacultyReviewsRepository>((ref) {
  return FacultyReviewsRepository(ref.watch(supabaseClientProvider), ref.watch(appDatabaseProvider));
});

final allCoursesCatalogProvider = FutureProvider<List<Map<String, String>>>((ref) async {
  final repo = ref.watch(facultyReviewsRepositoryProvider);
  return repo.getAllCourses();
});

final allSemestersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(facultyReviewsRepositoryProvider);
  return repo.getAllSemesters();
});

/// Reading reviews is local (approved reviews: scope `reviews`; your own: scope
/// `user`), so it works offline. Submitting/editing stays online-only.
class FacultyReviewsRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;

  FacultyReviewsRepository(this._supabase, this._db);

  static List<FacultyReview> _parse(Iterable<Map<String, dynamic>> rows) {
    final out = <FacultyReview>[];
    for (final r in rows) {
      try {
        out.add(FacultyReview.fromMap(r));
      } catch (_) {}
    }
    return out;
  }

  // Course picker (local catalog)
  Future<List<Map<String, String>>> getAllCourses() async {
    final rows = await _db.getRows('course_metadata');
    final list = rows
        .map((e) => {'code': '${e['code'] ?? ''}'.toUpperCase(), 'name': '${e['name'] ?? ''}'})
        .toList()
      ..sort((a, b) => a['code']!.compareTo(b['code']!));
    return list;
  }

  // Semester picker (local semesters, newest first)
  Future<List<Map<String, dynamic>>> getAllSemesters() async {
    final rows = await _db.getRows('semesters')
      ..sort((a, b) => ((b['portal_semester_id'] as num?) ?? 0).compareTo((a['portal_semester_id'] as num?) ?? 0));
    return rows
        .map((e) => {'code': '${e['code'] ?? ''}', 'title': '${e['title'] ?? ''}', 'is_active': e['is_active'] == true})
        .toList();
  }

  // All approved reviews for a faculty member
  Future<List<FacultyReview>> getApprovedReviews(String initials) async {
    final normalized = initials.trim().toUpperCase();
    final rows = (await _db.getRows('faculty_reviews'))
        .where((r) => r['status'] == 'approved' && '${r['faculty_initials']}'.trim().toUpperCase() == normalized)
        .toList()
      ..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    return _parse(rows);
  }

  Future<List<Map<String, dynamic>>> _myRows() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return const [];
    return (await _db.getRows('my_faculty_reviews')).where((r) => r['user_id'] == uid).toList();
  }

  // Current user's review for this faculty and course (if any)
  Future<FacultyReview?> getUserReview({required String initials, required String courseCode}) async {
    final i = initials.trim().toUpperCase();
    final c = courseCode.trim().toUpperCase();
    final row = (await _myRows())
        .where((r) => '${r['faculty_initials']}'.trim().toUpperCase() == i && '${r['course_code']}'.trim().toUpperCase() == c)
        .firstOrNull;
    return row == null ? null : _parse([row]).firstOrNull;
  }

  // All of the current user's reviews for this faculty member
  Future<List<FacultyReview>> getUserReviewsForFaculty(String initials) async {
    final i = initials.trim().toUpperCase();
    final rows = (await _myRows()).where((r) => '${r['faculty_initials']}'.trim().toUpperCase() == i).toList()
      ..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    return _parse(rows);
  }
  // Submit a new faculty review or update existing one
  Future<void> submitReview(FacultyReview review) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Must be logged in to submit a review.');

    // Ensure strictly one review per student per faculty member
    final existingReviews = await getUserReviewsForFaculty(review.facultyInitials);
    if (existingReviews.isNotEmpty) {
      final existing = existingReviews.first;
      final updated = FacultyReview(
        id: existing.id,
        userId: user.id,
        facultyInitials: review.facultyInitials,
        facultyName: review.facultyName,
        courseCode: review.courseCode,
        semester: review.semester,
        semesterCode: review.semesterCode,
        status: 'pending',
        deliveryType: review.deliveryType,
        gradeReceived: review.gradeReceived,
        clarityRating: review.clarityRating,
        gradingFairness: review.gradingFairness,
        examAlignment: review.examAlignment,
        officeHoursAccessibility: review.officeHoursAccessibility,
        attendanceStrictness: review.attendanceStrictness,
        workloadLevel: review.workloadLevel,
        slideReliance: review.slideReliance,
        quizFrequency: review.quizFrequency,
        textbookNeed: review.textbookNeed,
        traits: review.traits,
        examPrepTips: review.examPrepTips,
        reviewNote: review.reviewNote,
        wouldTakeAgain: review.wouldTakeAgain,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      await resubmitReview(updated);
      return;
    }

    final data = review.toMap();
    data['user_id'] = user.id;
    data['status'] = 'pending';
    data['admin_rejection_note'] = null;

    await _supabase.from('faculty_reviews').upsert(
          data,
          onConflict: 'user_id,faculty_initials,course_code',
        );
    SyncSignals.instance.request(reason: 'review submitted');
  }

  // Edit and resubmit a review (resets status to pending and clears rejection note)
  Future<void> resubmitReview(FacultyReview review) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Must be logged in.');

    final data = review.toMap();
    data['user_id'] = user.id;
    data['status'] = 'pending';
    data['admin_rejection_note'] = null;
    data['updated_at'] = DateTime.now().toIso8601String();

    await _supabase
        .from('faculty_reviews')
        .update(data)
        .eq('id', review.id)
        .eq('user_id', user.id);
    SyncSignals.instance.request(reason: 'review resubmitted');
  }

  // Delete own review
  Future<void> deleteReview(String reviewId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('faculty_reviews')
        .delete()
        .eq('id', reviewId)
        .eq('user_id', user.id);
    SyncSignals.instance.request(reason: 'review deleted');
  }
}
