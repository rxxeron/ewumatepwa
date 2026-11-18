import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/data/repos/local_writer.dart';
import '../../../../core/data/sync/scope_catalog.dart';
import '../../../../core/repositories/course_repository.dart';
import '../../../../core/repositories/profile_repository.dart';
import '../../../../core/repositories/auth_repository.dart';
import '../../../../core/providers/academic_providers.dart';
import '../../../../core/models/course_metadata.dart';

final courseSearchQueryProvider = StateProvider<String>((ref) => '');

final courseBrowserTabProvider = StateProvider<String>((ref) => 'available');

class CourseBrowserFilter {
  final String? faculty;
  final String? credits;
  final List<String> days;

  CourseBrowserFilter({
    this.faculty,
    this.credits,
    this.days = const [],
  });

  CourseBrowserFilter copyWith({
    String? faculty,
    String? credits,
    List<String>? days,
    bool clearFaculty = false,
    bool clearCredits = false,
  }) {
    return CourseBrowserFilter(
      faculty: clearFaculty ? null : (faculty ?? this.faculty),
      credits: clearCredits ? null : (credits ?? this.credits),
      days: days ?? this.days,
    );
  }

  bool get isEmpty => faculty == null && credits == null && days.isEmpty;
}

final courseBrowserFilterProvider = StateProvider<CourseBrowserFilter>((ref) => CourseBrowserFilter());

class PaginatedCoursesNotifier extends AsyncNotifier<List<CourseMetadata>> {
  int _offset = 0;
  final int _limit = 50;
  bool _hasMore = true;

  @override
  Future<List<CourseMetadata>> build() async {
    _offset = 0;
    _hasMore = true;
    return ref.watch(courseRepositoryProvider).getAllCourses(offset: _offset, limit: _limit);
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading || state.isRefreshing) return;

    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<List<CourseMetadata>>().copyWithPrevious(state);
    
    try {
      _offset += _limit;
      final activeSem = await ref.read(currentSemesterCodeProvider.future);
      if (activeSem == null) return;
      
      final newPage = await ref.read(courseRepositoryProvider).getSemesterCourses(activeSem);
      
      if (newPage.length < _limit) {
        _hasMore = false;
      }

      state = AsyncData([...state.value ?? [], ...newPage]);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  bool get hasMore => _hasMore;
}

final paginatedCoursesProvider = AsyncNotifierProvider<PaginatedCoursesNotifier, List<CourseMetadata>>(
  PaginatedCoursesNotifier.new,
);

final courseSearchResultProvider = FutureProvider<List<CourseMetadata>>((ref) async {
  final query = ref.watch(courseSearchQueryProvider).trim();
  final repo = ref.watch(courseRepositoryProvider);
  
  if (query.isEmpty) return [];
  final isValid = query.length >= 3 || 
      (query.length == 2 && ['CE', 'CS'].contains(query.toUpperCase()));
  if (!isValid) return [];

  return repo.searchCourses(query);
});

enum SemesterScope { active, upcoming }

final selectedSemesterScopeProvider = StateProvider<SemesterScope>((ref) => SemesterScope.active);

final currentSemCodeProvider = FutureProvider<String>((ref) async {
  final state = await ref.watch(academicStateProvider.future);
  return state?.currentSemesterCode ?? '';
});

final nextSemCodeProvider = FutureProvider<String>((ref) async {
  final state = await ref.watch(academicStateProvider.future);
  return state?.nextSemesterCode ?? '';
});

final selectedBrowserSemesterCodeProvider = FutureProvider<String>((ref) async {
  final scope = ref.watch(selectedSemesterScopeProvider);
  final state = await ref.watch(academicStateProvider.future);
  if (scope == SemesterScope.upcoming) {
    final next = state?.nextSemesterCode ?? '';
    if (next.isNotEmpty) return next;
  }
  return state?.currentSemesterCode ?? '';
});

/// Course codes the user has in the selected semester (enrollments + manual marks
/// entries), from local data — instant and offline.
final userEnrollmentsProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final targetSem = await ref.watch(selectedBrowserSemesterCodeProvider.future);
  if (targetSem.isEmpty) return [];
  final scope = ref.watch(selectedSemesterScopeProvider);
  final sem = normSemester(targetSem);

  final enrollments = (await ref.watch(localRowsProvider(('enrollments', sem)).future))
      .where((e) => e['user_id'] == user.id)
      .where((e) => scope != SemesterScope.upcoming || e['status'] == 'upcoming');
  final codes = {for (final e in enrollments) '${e['course_code']}'};

  if (scope != SemesterScope.upcoming) {
    final marks = await ref.watch(localRowsProvider(('semester_course_marks', sem)).future);
    codes.addAll(marks.where((m) => m['user_id'] == user.id).map((m) => '${m['course_code']}'));
  }
  return codes.where((c) => c.isNotEmpty && c != 'null').toList();
});
final browserAvailableCoursesProvider = FutureProvider<List<CourseMetadata>>((ref) async {
  final targetSem = await ref.watch(selectedBrowserSemesterCodeProvider.future);
  if (targetSem.isEmpty) return [];
  
  final completedCourseCodesStr = ref.watch(userProfileProvider.select((profileAsync) {
    return profileAsync.maybeWhen(
      data: (profile) {
        if (profile == null) return '';
        final history = profile.pastHistory;
        final codes = history.where((item) {
          if (item is! Map) return false;
          final grade = (item['grade'] as String?)?.toUpperCase() ?? '';
          // Only exclude if they have a real passing grade
          // If it's W, F, R, or empty, they might need to retake it
          return grade.isNotEmpty && 
                 grade != 'W' && 
                 grade != 'F' && 
                 grade != 'R' && 
                 grade != 'I' &&
                 grade != 'X';
        }).map((item) => (item['course_code'] as String?)?.toUpperCase() ?? '').toList();
        codes.sort();
        return codes.join(',');
      },
      orElse: () => '',
    );
  }));
  final completedCourseCodes = completedCourseCodesStr.split(',').where((e) => e.isNotEmpty).toSet();

  final allCourses = await ref.watch(semesterCoursesProvider(targetSem).future);
  return allCourses.where((course) => !completedCourseCodes.contains(course.code.toUpperCase())).toList();
});

final filteredAvailableCoursesProvider = Provider<AsyncValue<List<CourseMetadata>>>((ref) {
  final availableAsync = ref.watch(browserAvailableCoursesProvider);
  final filter = ref.watch(courseBrowserFilterProvider);

  if (filter.isEmpty) return availableAsync;

  return availableAsync.whenData((courses) {
    return courses.where((course) {
      // 1. Filter by Credits
      if (filter.credits != null && filter.credits!.isNotEmpty) {
        if (course.creditVal.toString() != filter.credits && 
            !course.creditVal.toString().startsWith(filter.credits!)) {
          return false;
        }
      }
      
      // Note: Faculty and Day filtering often requires reaching into Sections,
      // but for the high-level Metadata list, we primarily filter by what's available in the table.
      // If we need deep section filtering, we'd need to fetch sections for all courses first (expensive).
      // For now, we'll implement Metadata-level filtering.
      
      return true;
    }).toList();
  });
});

/// The user's enrollments in the selected semester with section time/room/faculty,
/// from local data. Rows with `_pending: true` are queued offline and not yet confirmed.
final userEnrollmentDetailsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final targetSem = await ref.watch(selectedBrowserSemesterCodeProvider.future);
  if (targetSem.isEmpty) return [];
  final scope = ref.watch(selectedSemesterScopeProvider);
  final sem = normSemester(targetSem);

  final enrollments = (await ref.watch(localRowsProvider(('enrollments', sem)).future))
      .where((e) => e['user_id'] == user.id)
      .where((e) => scope != SemesterScope.upcoming || e['status'] == 'upcoming')
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  if (enrollments.isEmpty) return enrollments;

  final sections = {
    for (final s in await ref.watch(localRowsProvider(('courses_$sem', null)).future)) '${s['id']}': s,
  };
  for (final enr in enrollments) {
    final sec = sections['${enr['section_id']}'];
    if (sec == null) continue;
    enr['faculty_initial'] = sec['faculty_initials'];
    final sched = sec['schedule_data'];
    if (sched is List && sched.isNotEmpty && sched.first is Map) {
      final first = sched.first as Map;
      enr['time'] = first['time'] ?? '${first['start_time']}-${first['end_time']}';
      enr['room'] = first['room'];
    }
  }
  return enrollments;
});