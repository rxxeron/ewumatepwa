import 'package:flutter/foundation.dart';
import '../../../core/data/db/app_database.dart';
import '../../../core/data/repos/local_queries.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/course_utils.dart';
import '../../dashboard/exception_repository.dart';
import '../widgets/attendance_sessions_tab.dart';

class AttendanceCalendarResult {
  final List<AttendanceSession> sessions;
  final Map<String, String> markedDates;
  final Map<String, String> dateTypes;
  final bool typesChanged;

  AttendanceCalendarResult({
    required this.sessions,
    required this.markedDates,
    required this.dateTypes,
    required this.typesChanged,
  });
}

class AttendanceCalendarService {
  /// Generates the semester class session timeline by cross-referencing:
  /// 1. Semester start & end dates from active_semester
  /// 2. User's routine grid cache (class weekdays and session types)
  /// 3. University calendar holidays
  /// 4. User's cancellations and makeup sessions
  static Future<AttendanceCalendarResult> generateSessions({
    required String courseCode,
    required String semesterCode,
    required String? userTrack,
    required Map<String, dynamic> existingMarksData,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    final resolvedTrack = CourseUtils.normalizeTrack(userTrack);
    final cleanSem = CourseUtils.cleanSemester(semesterCode);

    // 1. Semester start/end dates and 2. the weekly grid — both from the local database.
    final local = LocalQueries(AppDatabase.main);
    final activeSem = await local.activeSemester(resolvedTrack);
    final startDate = DateTime.tryParse('${activeSem?['classes_start_date'] ?? ''}') ??
        DateTime.now().subtract(const Duration(days: 45));
    final endDate = DateTime.tryParse('${activeSem?['classes_end_date'] ?? ''}') ??
        DateTime.now().add(const Duration(days: 45));
    final Map<String, dynamic> grid = await local.weeklyGrid(user.id, cleanSem);
    final String currentCourseCodeNormalized = courseCode.toUpperCase().replaceAll(' ', '');

    final List<Map<String, String>> scheduledTemplates = [];
    final Map<String, int> weekdayMap = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    for (final entry in grid.entries) {
      final day = entry.key;
      final dayClasses = entry.value;
      if (dayClasses is List) {
        for (final c in dayClasses) {
          final code = (c['courseCode'] ?? c['course_code'] ?? '').toString().toUpperCase().replaceAll(' ', '');
          if (CourseUtils.areEquivalent(code, currentCourseCodeNormalized)) {
            final startTime = (c['startTime'] ?? c['start_time'] ?? '').toString();
            final endTime = (c['endTime'] ?? c['end_time'] ?? '').toString();
            final isLab = CourseUtils.isLab(startTime, endTime, code);
            final type = CourseUtils.normalizeSessionType(c['type']?.toString() ?? (isLab ? 'Lab' : 'Theory'));
            scheduledTemplates.add({
              'day': day,
              'type': type,
            });
          }
        }
      }
    }

    // 3. Fetch academic calendar holidays (Offline-first)
    final tableName = CourseUtils.semesterTable(
      'calendar',
      cleanSem,
      cycleType: resolvedTrack,
    );

    final Set<String> holidayDates = {};
    final List<dynamic> calendarEvents = await local.calendarEvents(tableName);

    for (final ev in calendarEvents) {
      final dateStr = (ev['event_date'] ?? ev['date'] ?? '').toString();
      final title = (ev['title'] ?? ev['name'] ?? '').toString().toLowerCase();
      final isHoliday = ev['is_holiday'] == true ||
          ev['type']?.toString().toLowerCase() == 'holiday' ||
          title.contains('holiday') ||
          title.contains('vacation') ||
          title.contains('break') ||
          title.contains('leave') ||
          title.contains('off day') ||
          title.contains('no classes');
      if (isHoliday && dateStr.isNotEmpty) {
        holidayDates.add(dateStr);
      }
    }

    // 4. Fetch cancellations and makeups from schedule exceptions
    final Set<String> cancelledDates = {};
    final List<Map<String, dynamic>> courseMakeups = [];
    try {
      final exceptionsList = await ExceptionRepository().fetchExceptions();
      for (final ex in exceptionsList) {
        final exCourse = (ex['course_code'] ?? ex['courseCode'] ?? '').toString().toUpperCase().replaceAll(' ', '');
        if (CourseUtils.areEquivalent(exCourse, currentCourseCodeNormalized)) {
          final dateStr = ex['date']?.toString();
          final type = ex['type']?.toString();
          if (dateStr != null && dateStr.isNotEmpty) {
            if (type == 'cancel') {
              cancelledDates.add(dateStr);
            } else if (type == 'makeup' || type == 'manual') {
              courseMakeups.add(ex);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[Attendance] Exceptions fetch failed: $e');
    }

    // 5. Generate matching weekdays up to today's date
    final List<AttendanceSession> generatedSessions = [];
    final List<int> weekdaysInt = scheduledTemplates.map((t) => weekdayMap[t['day']!]!).toSet().toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime endLimit = endDate.isAfter(today) ? today : endDate;

    for (DateTime d = startDate; d.isBefore(endLimit) || d.isAtSameMomentAs(endLimit); d = d.add(const Duration(days: 1))) {
      if (weekdaysInt.contains(d.weekday)) {
        final dayName = DateFormat('EEEE').format(d);
        final dayTemplates = scheduledTemplates.where((t) => t['day'] == dayName).toList();
        for (final temp in dayTemplates) {
          final sType = CourseUtils.normalizeSessionType(temp['type']);
          generatedSessions.add(AttendanceSession(
            DateTime(d.year, d.month, d.day),
            sType,
          ));
        }
      }
    }

    // Load saved dates and types from DB
    final attendance = Map<String, dynamic>.from(existingMarksData['attendance'] ?? {});
    final datesRaw = Map<String, dynamic>.from(attendance['dates'] ?? {});
    final typesRaw = Map<String, dynamic>.from(attendance['types'] ?? {});
    final markedDates = Map<String, String>.from(datesRaw);
    final dateTypes = Map<String, String>.from(typesRaw);

    // Populate scheduled day types first
    for (final session in generatedSessions) {
      final dateStr = DateFormat('yyyy-MM-dd').format(session.date);
      final sessionType = CourseUtils.normalizeSessionType(session.type);
      final key = '${dateStr}_$sessionType';
      if (!dateTypes.containsKey(key)) {
        dateTypes[key] = sessionType;
      }
      if (!dateTypes.containsKey(dateStr)) {
        dateTypes[dateStr] = sessionType; // legacy fallback
      }
    }

    // Add makeup classes/manual entries that have occurred up to endLimit
    for (final makeup in courseMakeups) {
      final dateStr = makeup['date']?.toString() ?? '';
      final mDate = DateTime.tryParse(dateStr);
      if (mDate != null && (mDate.isBefore(endLimit) || mDate.isAtSameMomentAs(endLimit))) {
        final normalizedDate = DateTime(mDate.year, mDate.month, mDate.day);
        final sessionType = CourseUtils.normalizeSessionType(makeup['session_type']?.toString() ?? makeup['sessionType']?.toString());

        final exists = generatedSessions.any((s) => s.date == normalizedDate && s.type == sessionType);
        if (!exists) {
          generatedSessions.add(AttendanceSession(normalizedDate, sessionType));
        }
        final key = '${dateStr}_$sessionType';
        dateTypes[key] = sessionType;
        dateTypes[dateStr] = sessionType; // legacy fallback
      }
    }

    // Sort generated list in reverse order (newest first)
    generatedSessions.sort((a, b) {
      final cmp = b.date.compareTo(a.date);
      if (cmp != 0) return cmp;
      return a.type.compareTo(b.type);
    });

    // Auto-mark holidays and cancellations if not already set by user
    for (final session in generatedSessions) {
      final dateStr = DateFormat('yyyy-MM-dd').format(session.date);
      final sessionType = CourseUtils.normalizeSessionType(session.type);
      final key = '${dateStr}_$sessionType';
      if (!CourseUtils.isSessionMarked(markedDates, dateStr, sessionType)) {
        if (holidayDates.contains(dateStr)) {
          markedDates[key] = 'holiday';
        } else if (cancelledDates.contains(dateStr)) {
          markedDates[key] = 'cancelled';
        }
      }
    }

    // Check if type mappings changed
    bool typesChanged = false;
    for (final entry in dateTypes.entries) {
      if (typesRaw[entry.key]?.toString() != entry.value) {
        typesChanged = true;
        break;
      }
    }

    return AttendanceCalendarResult(
      sessions: generatedSessions,
      markedDates: markedDates,
      dateTypes: dateTypes,
      typesChanged: typesChanged,
    );
  }
}
