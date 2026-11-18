import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/supabase_config.dart';
import '../../core/data/data_providers.dart';
import '../../core/data/db/app_database.dart';
import '../../core/data/repos/local_queries.dart';
import '../../core/utils/course_utils.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    supabase: Supabase.instance.client,
    db: ref.watch(appDatabaseProvider),
  );
});

/// Builds the dashboard/routine payloads from the LOCAL database (synced by the
/// sync engine). No network, no TTL caches: the data changes when the server does.
class DashboardRepository {
  final SupabaseClient _supabase;
  final LocalQueries _local;

  DashboardRepository({
    SupabaseClient? supabase,
    required AppDatabase db,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _local = LocalQueries(db);

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Semesters whose weekly grid was found empty this run: ask the server to
  /// build it once (it arrives through sync), instead of on every refresh.
  static final Set<String> _gridRebuildRequested = {};

  void _requestGridOnce(String userId, String semesterCode) {
    if (!_gridRebuildRequested.add('$userId|${CourseUtils.cleanSemester(semesterCode)}')) return;
    unawaited(syncWeeklySchedule(userId));
  }

  Future<Map<String, dynamic>?> _getCachedActiveSemesterDates(String track) =>
      _local.activeSemester(CourseUtils.normalizeTrack(track));

  /// The New Simplified Dashboard Fetch
  /// 1. Weekly Grid (user_semester_states)
  /// 2. Schedule Exceptions (schedule_exceptions)
  /// 3. Holiday (calendar_[semester])
  /// 4. Top 3 Upcoming Tasks (tasks)
  Future<Map<String, dynamic>> getSimplifiedDashboardData(
    String semesterCode,
    DateTime date, {
    String? track,
    DateTime? profileUpdatedAt,
  }) async {
    final effectiveUserId = _userId;
    if (effectiveUserId == null) return {};

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dayName = DateFormat('EEEE').format(date);

    // Determine student track (PHRM/LAW vs Standard)
    final programName = track?.toUpperCase() ?? '';
    final bool isBiSemester = programName.contains('PHRM') ||
        programName.contains('LAW') ||
        programName.contains('LLB') ||
        programName.contains('BI');

    {
      // 1. Fetch relevant track configuration
      final standardTable = CourseUtils.semesterTable(
        'calendar',
        semesterCode,
        cycleType: 'tri_semester',
      );
      
      // Professional calendar is ONLY needed for PHRM/LLB students (who can take hybrid courses)
      final phrmTable = isBiSemester 
          ? CourseUtils.semesterTable('calendar', semesterCode, cycleType: 'bi_semester')
          : null;

      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final results = await Future.wait<dynamic>([
        // [0] Weekly grid (row shaped like the old select)
        _local.weeklyGrid(effectiveUserId, semesterCode).then((g) => {'weekly_grid_cache': g}),
        // [1] Date-specific exceptions
        _local.exceptions(effectiveUserId, date: dateStr),
        // [2] Standard (Tri) events for dateStr
        _local.calendarEvents(standardTable, date: dateStr),
        // [3] Professional (Bi) events for dateStr
        phrmTable != null ? _local.calendarEvents(phrmTable, date: dateStr) : Future.value(<Map<String, dynamic>>[]),
        // [4] Open tasks due from a week ago on, soonest first, max 10
        _local.tasks(effectiveUserId, semesterCode: semesterCode).then((all) {
          final open = all.where((t) {
            if (t['is_completed'] == true) return false;
            final due = DateTime.tryParse('${t['due_date']}');
            return due != null && !due.isBefore(weekAgo);
          }).toList()
            ..sort((a, b) => '${a['due_date']}'.compareTo('${b['due_date']}'));
          return open.take(10).toList();
        }),
        // [5, 6] Classes End/Start Dates
        _getCachedActiveSemesterDates('tri_semester'),
        _getCachedActiveSemesterDates('bi_semester'),
      ]);

      var weeklyGrid =
          (results[0] as Map<String, dynamic>?)?['weekly_grid_cache']
              as Map<String, dynamic>? ??
          {};
      final exceptions = List<Map<String, dynamic>>.from(
        results[1] as List? ?? [],
      );
      final standardEvents = List<Map<String, dynamic>>.from(
        (results[2] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final phrmEvents = List<Map<String, dynamic>>.from(
        (results[3] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final tasksRaw = List<Map<String, dynamic>>.from(
        results[4] as List? ?? [],
      );

      final stdEndDateStr =
          (results[5] as Map<String, dynamic>?)?['classes_end_date']
              ?.toString();
      final stdStartDateStr =
          (results[5] as Map<String, dynamic>?)?['classes_start_date']
              ?.toString();
      final phrmEndDateStr =
          (results[6] as Map<String, dynamic>?)?['classes_end_date']
              ?.toString();
      final phrmStartDateStr =
          (results[6] as Map<String, dynamic>?)?['classes_start_date']
              ?.toString();

      if (weeklyGrid.isEmpty) _requestGridOnce(effectiveUserId, semesterCode);

      // 2. Evaluate Standard (Tri) Track Local State
      String stdDay = dayName;
      bool stdIsHoliday = false;
      String stdReason = '';
      for (final event in standardEvents) {
        final title = (event['title'] ?? event['name'] ?? '').toString();
        final lowerTitle = title.toLowerCase();
        if (lowerTitle.contains('regular sunday')) {
          stdDay = 'Sunday';
        } else if (lowerTitle.contains('regular monday')) {
          stdDay = 'Monday';
        } else if (lowerTitle.contains('regular tuesday')) {
          stdDay = 'Tuesday';
        } else if (lowerTitle.contains('regular wednesday')) {
          stdDay = 'Wednesday';
        } else if (lowerTitle.contains('regular thursday')) {
          stdDay = 'Thursday';
        }

        if (_isActualHoliday(event, lowerTitle)) {
          stdIsHoliday = true;
          stdReason = title.isNotEmpty ? title : 'Holiday';
        }
      }

      // 3. Evaluate Professional (Bi) Track Local State
      String phrmDay = dayName;
      bool phrmIsHoliday = false;
      String phrmReason = '';
      for (final event in phrmEvents) {
        final title = (event['title'] ?? event['name'] ?? '').toString();
        final lowerTitle = title.toLowerCase();
        if (lowerTitle.contains('regular sunday')) {
          phrmDay = 'Sunday';
        } else if (lowerTitle.contains('regular monday')) {
          phrmDay = 'Monday';
        } else if (lowerTitle.contains('regular tuesday')) {
          phrmDay = 'Tuesday';
        } else if (lowerTitle.contains('regular wednesday')) {
          phrmDay = 'Wednesday';
        } else if (lowerTitle.contains('regular thursday')) {
          phrmDay = 'Thursday';
        }

        if (_isActualHoliday(event, lowerTitle)) {
          phrmIsHoliday = true;
          phrmReason = title.isNotEmpty ? title : 'Holiday';
        }
      }

      // 4. Check if student's track is on Holiday (University-wide or Track-specific)
      final bool isTodayHoliday = isBiSemester
          ? (phrmIsHoliday || stdIsHoliday)
          : stdIsHoliday;
      final String holidayReason = isBiSemester
          ? (phrmReason.isNotEmpty ? phrmReason : stdReason)
          : (stdReason.isNotEmpty ? stdReason : phrmReason);

      if (isTodayHoliday) {
        final payload = {
          'status': 'holiday',
          'reason': holidayReason.isNotEmpty ? holidayReason : 'Holiday',
          'template': <Map<String, dynamic>>[], // Zero template classes on a holiday!
          'exceptions': exceptions,
          'tasks': tasksRaw,
          'weekly_grid': weeklyGrid,
          'date': date,
          'dateStr': dateStr,
        };
        return payload;
      }

      // 5. Build combined classes with Independent Tracking
      List<Map<String, dynamic>> hybridClasses = [];

      bool isStdOver =
          stdEndDateStr != null && dateStr.compareTo(stdEndDateStr) > 0;
      bool isStdNotStarted =
          stdStartDateStr != null && dateStr.compareTo(stdStartDateStr) < 0;
      bool isPhrmOver =
          phrmEndDateStr != null && dateStr.compareTo(phrmEndDateStr) > 0;
      bool isPhrmNotStarted =
          phrmStartDateStr != null && dateStr.compareTo(phrmStartDateStr) < 0;

      // Pull Standard Courses (Non-PHRM/LAW)
      if (!stdIsHoliday && !isStdOver && !isStdNotStarted) {
        final stdClasses = List<Map<String, dynamic>>.from(
          weeklyGrid[stdDay] ?? [],
        );
        hybridClasses.addAll(
          stdClasses.where((c) {
            final code = (c['courseCode'] ?? c['course_code'] ?? '')
                .toString()
                .toUpperCase();
            return !code.startsWith('PHRM') && !code.startsWith('LAW');
          }),
        );
      }

      // Pull Professional Courses (PHRM/LAW)
      if (!phrmIsHoliday && !isPhrmOver && !isPhrmNotStarted) {
        final phClasses = List<Map<String, dynamic>>.from(
          weeklyGrid[phrmDay] ?? [],
        );
        hybridClasses.addAll(
          phClasses.where((c) {
            final code = (c['courseCode'] ?? c['course_code'] ?? '')
                .toString()
                .toUpperCase();
            return code.startsWith('PHRM') || code.startsWith('LAW');
          }),
        );
      }

      hybridClasses.sort(
        (a, b) => (a['startTime'] ?? a['start_time'] ?? '')
            .toString()
            .compareTo((b['startTime'] ?? b['start_time'] ?? '').toString()),
      );

      // 6. Status Calculation for non-holiday
      String status = (hybridClasses.isEmpty && exceptions.isEmpty)
          ? 'chill'
          : 'normal';
      String reason = '';

      if (hybridClasses.isEmpty) {
        if (isPhrmOver && isStdOver) {
          status = 'chill';
          reason = 'The semester classes have officially concluded.';
        } else if (isPhrmNotStarted && isStdNotStarted) {
          status = 'chill';
          reason = 'The semester classes haven\'t officially started yet.';
        }
      }

      final payload = {
        'status': status,
        'reason': reason,
        'template': hybridClasses,
        'exceptions': exceptions,
        'tasks': tasksRaw,
        'weekly_grid': weeklyGrid,
        'date': date,
        'dateStr': dateStr,
      };
      return payload;
    }
  }

  /// Triggers the sync-schedule Edge Function to regenerate the weekly_grid_cache.
  Future<void> syncWeeklySchedule(String userId) async {
    try {
      debugPrint('[Dashboard] Proactively triggering sync-schedule (No-JWT) for: $userId');
      final functionsUrl = '${AppConfig.getSupabaseUrl}/functions/v1';
      final uri = Uri.parse('$functionsUrl/sync-schedule');
      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': AppConfig.getSupabaseAnonKey,
        },
        body: jsonEncode({
          'user_id': userId,
        }),
      );
    } catch (e) {
      debugPrint('[Dashboard] Proactive sync error: $e');
    }
  }

  bool _isActualHoliday(Map<String, dynamic> event, String lowerTitle) {
    if (event['is_holiday'] == true ||
        event['type']?.toString().toLowerCase() == 'holiday') {
      return true;
    }
    if (lowerTitle.contains('holiday') ||
        lowerTitle.contains('vacation') ||
        lowerTitle.contains('break') ||
        lowerTitle.contains('leave') ||
        lowerTitle.contains('off day') ||
        lowerTitle.contains('day off') ||
        lowerTitle.contains('no classes') ||
        lowerTitle.contains('university closed') ||
        lowerTitle.contains('closed') ||
        lowerTitle.contains('eid') ||
        lowerTitle.contains('puja')) {
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> _fetchHolidayDirect(
    String semesterCode,
    String dateStr, {
    String? track,
  }) async {
    try {
      final resolvedTrack = track ?? 'tri_semester';
      final tableName = CourseUtils.semesterTable(
        'calendar',
        semesterCode,
        cycleType: resolvedTrack,
      );
      final res = await _local.calendarEvents(tableName);

      if (res.isNotEmpty) {
        final matches = res.where((d) {
          final dDate = (d['event_date'] ?? d['date'] ?? d['date_string'] ?? '')
              .toString();
          return dDate == dateStr;
        }).toList();

        if (matches.isNotEmpty) {
          // Prioritize holiday match if multiple events exist for this date
          for (final ev in matches) {
            final title = (ev['title'] ?? ev['name'] ?? '').toString().toLowerCase();
            if (_isActualHoliday(ev, title)) {
              return ev;
            }
          }
          return matches.first;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Preserve existing methods for backward compatibility but mark them as potentially cache-heavy/deprecated if needed
  Stream<Map<String, dynamic>> getDashboardDataStream(
    String semesterCode,
    DateTime date, {
    String? track,
  }) {
    // Actually, let's keep it but make it just call the simplified future one-time if user wants no cache
    final controller = StreamController<Map<String, dynamic>>();
    getSimplifiedDashboardData(semesterCode, date, track: track)
        .then((data) {
          if (!controller.isClosed) controller.add(data);
        })
        .catchError((e) {
          if (!controller.isClosed) controller.addError(e);
        });
    return controller.stream;
  }

  /// Legacy compat or direct fetch
  Future<Map<String, dynamic>> getDashboardDataFuture(
    String semesterCode,
    DateTime date, {
    String? track,
  }) async {
    final uid = _userId;
    if (uid == null) return {};

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dayName = DateFormat('EEEE').format(date);

    final results = await Future.wait<dynamic>([
      _local.weeklyGrid(uid, semesterCode).then((g) => <String, dynamic>{'weekly_grid_cache': g}),
      _local.exceptions(uid, date: dateStr),
      _fetchHolidayDirect(semesterCode, dateStr, track: track),
    ]);

    final templateData = results[0] as Map<String, dynamic>?;
    final exceptions = List<Map<String, dynamic>>.from(
      results[1] as List? ?? [],
    );
    final holidayData = results[2] as Map<String, dynamic>?;

    String effectiveDayName = dayName;
    bool isHoliday = false;
    String reason = '';

    if (holidayData != null) {
      String title = (holidayData['title'] ?? holidayData['name'] ?? '')
          .toString()
          .toLowerCase();
      if (title.contains('regular sunday classes')) {
        effectiveDayName = 'Sunday';
      } else if (title.contains('regular monday classes')) {
        effectiveDayName = 'Monday';
      } else if (title.contains('regular tuesday classes')) {
        effectiveDayName = 'Tuesday';
      } else if (title.contains('regular wednesday classes')) {
        effectiveDayName = 'Wednesday';
      } else if (title.contains('regular thursday classes')) {
        effectiveDayName = 'Thursday';
      } else if (_isActualHoliday(holidayData, title)) {
        isHoliday = true;
        reason = (holidayData['title'] ?? holidayData['name'] ?? 'Holiday')
            .toString();
      }
    }

    final weeklyGrid =
        templateData?['weekly_grid_cache'] as Map<String, dynamic>? ?? {};
    final dayClasses = List<Map<String, dynamic>>.from(
      weeklyGrid[effectiveDayName] ?? [],
    );

    return {
      'status': isHoliday
          ? 'holiday'
          : (dayClasses.isEmpty && exceptions.isEmpty ? 'chill' : 'normal'),
      'reason': reason,
      'template': dayClasses,
      'exceptions': exceptions,
      'date': date,
      'dateStr': dateStr,
    };
  }

  Future<Map<String, dynamic>> getScheduleFuture(String semesterCode) async {
    return getDashboardDataFuture(semesterCode, DateTime.now());
  }

  Future<List<Map<String, dynamic>>> getTwoWeekSchedule(
    String semesterCode, {
    String? track,
    int daysBack = 0,
  }) async {
    final uid = _userId;
    if (uid == null) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(Duration(days: daysBack));
    final twoWeeksLater = today.add(const Duration(days: 14));
    final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(twoWeeksLater);

    try {
      // Determine track
      final programName = track?.toUpperCase() ?? '';
      final bool isBiSemester = programName.contains('PHRM') ||
          programName.contains('LAW') ||
          programName.contains('LLB');

      String? standardTable;
      String? phrmTable;

      if (!isBiSemester) {
        standardTable = CourseUtils.semesterTable(
          'calendar',
          semesterCode,
          cycleType: 'tri_semester',
        );
      } else {
        phrmTable = CourseUtils.semesterTable(
          'calendar',
          semesterCode,
          cycleType: 'bi_semester',
        );
      }

      final results = await Future.wait<dynamic>([
        _local.weeklyGrid(uid, semesterCode).then((g) => <String, dynamic>{'weekly_grid_cache': g}),
        _local.exceptions(uid, from: startDateStr, to: endDateStr),
        standardTable != null
            ? _local.calendarEvents(standardTable, from: startDateStr, to: endDateStr)
            : Future.value(<Map<String, dynamic>>[]),
        phrmTable != null
            ? _local.calendarEvents(phrmTable, from: startDateStr, to: endDateStr)
            : Future.value(<Map<String, dynamic>>[]),
        _getCachedActiveSemesterDates('tri_semester'),
        _getCachedActiveSemesterDates('bi_semester'),
      ]);

      final weeklyGrid =
          (results[0] as Map<String, dynamic>?)?['weekly_grid_cache']
              as Map<String, dynamic>? ??
          {};

      if (weeklyGrid.isEmpty) _requestGridOnce(uid, semesterCode);

      bool isOverallPhrmUser = false;
      for (var dayClasses in weeklyGrid.values) {
        if (dayClasses is List) {
          for (var c in dayClasses) {
            final code = (c['courseCode'] ?? c['course_code'] ?? '')
                .toString()
                .toUpperCase();
            if (code.startsWith('PHRM') || code.startsWith('LAW')) {
              isOverallPhrmUser = true;
              break;
            }
          }
        }
        if (isOverallPhrmUser) break;
      }

      final exceptionsAll = List<Map<String, dynamic>>.from(
        results[1] as List? ?? [],
      );
      final stdHolidays = List<Map<String, dynamic>>.from(
        results[2] as List? ?? [],
      );
      final phrmHolidays = List<Map<String, dynamic>>.from(
        results[3] as List? ?? [],
      );

      final stdEndDateStr =
          (results[4] as Map<String, dynamic>?)?['classes_end_date']
              ?.toString();
      final stdStartDateStr =
          (results[4] as Map<String, dynamic>?)?['classes_start_date']
              ?.toString();
      final phrmEndDateStr =
          (results[5] as Map<String, dynamic>?)?['classes_end_date']
              ?.toString();
      final phrmStartDateStr =
          (results[5] as Map<String, dynamic>?)?['classes_start_date']
              ?.toString();

      List<Map<String, dynamic>> finalDays = [];

      for (int i = -daysBack; i < 14; i++) {
        final date = today.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final dayName = DateFormat('EEEE').format(date);

        final dateExceptions = exceptionsAll
            .where((e) => e['date'] == dateStr)
            .toList();
        final stdHolMatches = stdHolidays.where((h) {
          final dDate = (h['event_date'] ?? h['date'] ?? h['date_string'] ?? '')
              .toString();
          return dDate == dateStr;
        }).toList();
        final stdHol = stdHolMatches.isNotEmpty ? stdHolMatches.first : null;

        final phrmHolMatches = phrmHolidays.where((h) {
          final dDate = (h['event_date'] ?? h['date'] ?? h['date_string'] ?? '')
              .toString();
          return dDate == dateStr;
        }).toList();
        final phrmHol = phrmHolMatches.isNotEmpty ? phrmHolMatches.first : null;

        String stdDay = dayName;
        bool stdIsHoliday = false;
        String stdReason = '';
        if (stdHol != null) {
          String title = (stdHol['title'] ?? stdHol['name'] ?? '')
              .toString()
              .toLowerCase();
          if (title.contains('regular sunday')) {
            stdDay = 'Sunday';
          } else if (title.contains('regular monday')) {
            stdDay = 'Monday';
          } else if (title.contains('regular tuesday')) {
            stdDay = 'Tuesday';
          } else if (title.contains('regular wednesday')) {
            stdDay = 'Wednesday';
          } else if (title.contains('regular thursday')) {
            stdDay = 'Thursday';
          } else if (_isActualHoliday(stdHol, title)) {
            stdIsHoliday = true;
            stdReason = (stdHol['title'] ?? stdHol['name'] ?? 'Holiday')
                .toString();
          }
        }

        String phrmDay = dayName;
        bool phrmIsHoliday = false;
        String phrmReason = '';
        if (phrmHol != null) {
          String title = (phrmHol['title'] ?? phrmHol['name'] ?? '')
              .toString()
              .toLowerCase();
          if (title.contains('regular sunday')) {
            phrmDay = 'Sunday';
          } else if (title.contains('regular monday')) {
            phrmDay = 'Monday';
          } else if (title.contains('regular tuesday')) {
            phrmDay = 'Tuesday';
          } else if (title.contains('regular wednesday')) {
            phrmDay = 'Wednesday';
          } else if (title.contains('regular thursday')) {
            phrmDay = 'Thursday';
          } else if (_isActualHoliday(phrmHol, title)) {
            phrmIsHoliday = true;
            phrmReason = (phrmHol['title'] ?? phrmHol['name'] ?? 'Holiday')
                .toString();
          }
        } else if (stdHol != null) {
          String title = (stdHol['title'] ?? stdHol['name'] ?? '')
              .toString()
              .toLowerCase();
          bool isSwap =
              title.contains('regular sunday') ||
              title.contains('regular monday') ||
              title.contains('regular tuesday') ||
              title.contains('regular wednesday') ||
              title.contains('regular thursday');
          if (isSwap || _isActualHoliday(stdHol, title)) {
            if (title.contains('regular sunday')) {
              phrmDay = 'Sunday';
            } else if (title.contains('regular monday')) {
              phrmDay = 'Monday';
            } else if (title.contains('regular tuesday')) {
              phrmDay = 'Tuesday';
            } else if (title.contains('regular wednesday')) {
              phrmDay = 'Wednesday';
            } else if (title.contains('regular thursday')) {
              phrmDay = 'Thursday';
            } else {
              phrmIsHoliday = true;
              phrmReason = (stdHol['title'] ?? stdHol['name'] ?? 'Holiday')
                  .toString();
            }
          }
        }

        List<Map<String, dynamic>> combinedClasses = [];
        bool isStdOver =
            stdEndDateStr != null && dateStr.compareTo(stdEndDateStr) > 0;
        bool isStdNotStarted =
            stdStartDateStr != null && dateStr.compareTo(stdStartDateStr) < 0;
        bool isPhrmOver =
            phrmEndDateStr != null && dateStr.compareTo(phrmEndDateStr) > 0;
        bool isPhrmNotStarted =
            phrmStartDateStr != null && dateStr.compareTo(phrmStartDateStr) < 0;

        if (!stdIsHoliday && !isStdOver && !isStdNotStarted) {
          final stdClasses = List<Map<String, dynamic>>.from(
            weeklyGrid[stdDay] ?? [],
          );
          combinedClasses.addAll(
            stdClasses.where((c) {
              final code = (c['courseCode'] ?? c['course_code'] ?? '')
                  .toString()
                  .toUpperCase();
              return !code.startsWith('PHRM') && !code.startsWith('LAW');
            }),
          );
        }
        if (!phrmIsHoliday && !isPhrmOver && !isPhrmNotStarted) {
          final phClasses = List<Map<String, dynamic>>.from(
            weeklyGrid[phrmDay] ?? [],
          );
          combinedClasses.addAll(
            phClasses.where((c) {
              final code = (c['courseCode'] ?? c['course_code'] ?? '')
                  .toString()
                  .toUpperCase();
              return code.startsWith('PHRM') || code.startsWith('LAW');
            }),
          );
        }

        combinedClasses.sort(
          (a, b) => (a['startTime'] ?? a['start_time'] ?? '')
              .toString()
              .compareTo((b['startTime'] ?? b['start_time'] ?? '').toString()),
        );
        bool isUserPhrmTrack = combinedClasses.any(
          (c) =>
              (c['courseCode'] ?? c['course_code'] ?? '')
                  .toString()
                  .toUpperCase()
                  .startsWith('PHRM') ||
              (c['courseCode'] ?? c['course_code'] ?? '')
                  .toString()
                  .toUpperCase()
                  .startsWith('LAW'),
        );
        bool primaryHoliday = isUserPhrmTrack ? phrmIsHoliday : stdIsHoliday;
        // Apply fallback standard holiday overrides to UI if both are empty
        if (isUserPhrmTrack && !primaryHoliday && stdIsHoliday) {
          bool stdIsActual = _isActualHoliday(
            stdHol!,
            (stdHol['title'] ?? stdHol['name'] ?? '').toString().toLowerCase(),
          );
          if (stdIsActual) {
            primaryHoliday = true;
            phrmReason = (stdHol['title'] ?? stdHol['name'] ?? 'Holiday')
                .toString();
          }
        }
        String primaryReason = isUserPhrmTrack ? phrmReason : stdReason;

        List<Map<String, dynamic>> dailyEvents = [];
        if (stdHol != null) {
          if (isOverallPhrmUser) {
            String title = (stdHol['title'] ?? stdHol['name'] ?? '')
                .toString()
                .toLowerCase();
            bool isSwap =
                title.contains('regular sunday') ||
                title.contains('regular monday') ||
                title.contains('regular tuesday') ||
                title.contains('regular wednesday') ||
                title.contains('regular thursday');
            if (stdIsHoliday || isSwap) {
              dailyEvents.add(stdHol);
            }
          } else {
            dailyEvents.add(stdHol);
          }
        }
        if (phrmHol != null && isOverallPhrmUser) {
          dailyEvents.add(phrmHol);
        }

        finalDays.add({
          'date': date,
          'dateStr': dateStr,
          'isHoliday': primaryHoliday,
          'holidayReason': primaryReason,
          'events': dailyEvents,
          'status': (combinedClasses.isEmpty && dateExceptions.isEmpty)
              ? (primaryHoliday ? 'holiday' : 'chill')
              : 'normal',
          'template': combinedClasses,
          'exceptions': dateExceptions,
        });
      }
      return finalDays;
    } catch (e) {
      return [];
    }
  }
}
