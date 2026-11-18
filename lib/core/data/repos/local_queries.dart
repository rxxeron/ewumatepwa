import '../db/app_database.dart';
import '../sync/scope_catalog.dart';

/// Read helpers over the local database, shaped like the rows the server used
/// to return, so existing feature logic can switch data source without changes.
class LocalQueries {
  final AppDatabase db;
  LocalQueries(this.db);

  /// `user_semester_states.weekly_grid_cache` for a semester (any spelling of its code).
  Future<Map<String, dynamic>> weeklyGrid(String userId, String semesterCode) async {
    final sem = normSemester(semesterCode);
    final rows = await db.getRows('user_semester_states', semester: sem);
    final row = rows.where((r) => r['user_id'] == userId).firstOrNull;
    final grid = row?['weekly_grid_cache'];
    return grid is Map ? Map<String, dynamic>.from(grid) : <String, dynamic>{};
  }

  /// Schedule exceptions of the user on one date or within [from]..[to] (yyyy-MM-dd, inclusive).
  Future<List<Map<String, dynamic>>> exceptions(String userId, {String? date, String? from, String? to}) async {
    final rows = await db.getRows('schedule_exceptions');
    return rows.where((r) {
      if (r['user_id'] != userId) return false;
      final d = '${r['date']}';
      if (date != null) return d == date;
      if (from != null && d.compareTo(from) < 0) return false;
      if (to != null && d.compareTo(to) > 0) return false;
      return true;
    }).toList();
  }

  /// Rows of `calendar_<sem>` or `calendar_<sem>_phrm_llb` on a date / in a range.
  Future<List<Map<String, dynamic>>> calendarEvents(String table, {String? date, String? from, String? to}) async {
    final rows = await db.getRows(table);
    return rows.where((r) {
      final d = '${r['event_date'] ?? r['date'] ?? ''}';
      if (date != null) return d == date;
      if (from != null && d.compareTo(from) < 0) return false;
      if (to != null && d.compareTo(to) > 0) return false;
      return true;
    }).toList();
  }

  /// `active_semester` row of a track.
  Future<Map<String, dynamic>?> activeSemester(String track) async {
    final rows = await db.getRows('active_semester');
    return rows.where((r) => r['track'] == track).firstOrNull;
  }

  /// The user's tasks, optionally only for a semester (rows without a semester are included).
  Future<List<Map<String, dynamic>>> tasks(String userId, {String? semesterCode}) async {
    final sem = semesterCode == null ? null : normSemester(semesterCode);
    final rows = await db.getRows('tasks');
    return rows.where((r) {
      if (r['user_id'] != null && r['user_id'] != userId) return false;
      if (sem == null) return true;
      final s = r['semester_code'];
      return s == null || normSemester('$s') == sem;
    }).toList();
  }
}
