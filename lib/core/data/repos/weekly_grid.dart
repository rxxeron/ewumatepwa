/// Dart port of `generateTemplate()` in backend/supabase/functions/sync-schedule.
/// Used to show the routine immediately after an offline enroll/drop/switch;
/// the server rebuilds the authoritative grid when the change syncs, and that
/// replaces this local one. Keep the two in step.
library;

const _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const _ewuDayCode = {
  'Sunday': 'S',
  'Monday': 'M',
  'Tuesday': 'T',
  'Wednesday': 'W',
  'Thursday': 'R',
  'Friday': 'F',
  'Saturday': 'A',
};

const _masterPrograms = {
  'AIML', 'EMBA', 'LLM', 'M_PHARM', 'MA_ENG_40', 'MA_ENG_45', 'MA_TESOL_40', 'MA_TESOL_42',
  'MA_TESOL_48', 'MBA', 'MDS', 'MPRHGD', 'MS_CSE', 'MS_DSA', 'MSC_AIML', 'MSC_CYS', 'MSCCSE',
  'MSS_ECO', 'PGDED', 'PPDM',
};

/// [sections]: rows of `courses_<sem>` (course_code, course_name, schedule_data).
Map<String, List<Map<String, dynamic>>> buildWeeklyGrid(List<Map<String, dynamic>> sections, {String? programCode}) {
  final isMaster = programCode != null && _masterPrograms.contains(programCode.toUpperCase());
  final grid = <String, List<Map<String, dynamic>>>{};
  for (final day in _days) {
    final code = _ewuDayCode[day]!;
    final classes = <Map<String, dynamic>>[];
    for (final course in sections) {
      final sessions = course['schedule_data'];
      if (sessions is! List) continue;
      for (final s in sessions.whereType<Map>()) {
        if (!'${s['day'] ?? ''}'.contains(code)) continue;
        classes.add({
          'courseCode': course['course_code'],
          'courseName': course['course_name'],
          'startTime': s['startTime'] ?? s['start_time'] ?? 'TBA',
          'endTime': s['endTime'] ?? s['end_time'] ?? 'TBA',
          'room': s['room'] ?? 'TBA',
          'type': isMaster ? 'Theory' : (s['type'] ?? 'Theory'),
          'faculty': s['faculty'] ?? s['faculty_initials'] ?? '',
        });
      }
    }
    grid[day] = classes;
  }
  return grid;
}
