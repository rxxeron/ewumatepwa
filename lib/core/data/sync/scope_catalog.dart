/// Client mirror of the server's `sync.table_map` (backend/supabase/sync_v2/001_core_up.sql).
/// Keep the two in step: a table the server syncs but the client does not list is
/// simply never pulled.
library;

enum PullStyle {
  /// Rows written since the cursor, plus tombstones.
  delta,

  /// Whole table every time it changes (small tables / tables rebuilt server-side).
  full,
}

class ScopeTable {
  /// Server table name.
  final String server;

  /// Local table name in `synced_rows.tbl` (differs only when one server table is in two scopes).
  final String local;
  final List<String> pk;
  final PullStyle style;

  const ScopeTable(this.server, {String? local, this.pk = const ['id'], this.style = PullStyle.delta})
      : local = local ?? server;

  /// Same format as the server's sync.pk_expr(): single column as text, composite joined by '|'.
  String rowIdOf(Map<String, dynamic> row) =>
      pk.length == 1 ? '${row[pk.first]}' : pk.map((c) => '${row[c] ?? ''}').join('|');
}

/// Canonical semester key used everywhere locally: lowercase, no spaces/dashes/underscores,
/// name before year ("Fall 2026", "FALL_2026", "2026-fall" -> "fall2026").
/// Matches CourseUtils.cleanSemester and the server's sync.norm_semester().
String normSemester(String? s) {
  final c = (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
  final yearFirst = RegExp(r'^(\d{4})([a-z]+)$').firstMatch(c);
  return yearFirst == null ? c : '${yearFirst.group(2)}${yearFirst.group(1)}';
}

class ScopeCatalog {
  ScopeCatalog._();

  static const userTables = <ScopeTable>[
    ScopeTable('profiles'),
    ScopeTable('enrollments'),
    ScopeTable('completed_courses'),
    ScopeTable('semester_course_marks'),
    ScopeTable('semester_summaries'),
    ScopeTable('semester_analytics'),
    ScopeTable('user_semester_states', pk: ['user_id', 'semester_code']),
    ScopeTable('schedule_exceptions'),
    ScopeTable('tasks'),
    ScopeTable('user_drafts'),
    // The user's own reviews (any status). Approved reviews of everyone live under 'faculty_reviews'.
    ScopeTable('faculty_reviews', local: 'my_faculty_reviews'),
  ];

  static const notifTables = <ScopeTable>[ScopeTable('notifications')];

  static const metaTables = <ScopeTable>[
    ScopeTable('active_semester', pk: ['track'], style: PullStyle.full),
    ScopeTable('semesters', pk: ['code'], style: PullStyle.full),
  ];

  static const referenceTables = <ScopeTable>[
    ScopeTable('programs', pk: ['program_code'], style: PullStyle.full),
    ScopeTable('grade_scale', pk: ['grade', 'policy'], style: PullStyle.full),
    ScopeTable('scholarship_policies', style: PullStyle.full),
    ScopeTable('tutorials', style: PullStyle.full),
    ScopeTable('app_config', pk: ['key'], style: PullStyle.full),
    ScopeTable('course_metadata', pk: ['code']),
  ];

  static const facultyTables = <ScopeTable>[
    ScopeTable('faculty_master'),
    ScopeTable('faculty_office_hours'),
  ];

  static const reviewTables = <ScopeTable>[ScopeTable('faculty_reviews')];

  static String userScope(String uid) => 'user:$uid';
  static String notifsScope(String uid) => 'notifs:$uid';
  static String coursesScope(String sem) => 'courses:${normSemester(sem)}';
  static String calendarScope(String sem) => 'calendar:${normSemester(sem)}';

  /// Tables of a scope. [semesterTables] = server's list of existing per-semester tables
  /// (from sync_check), so a missing `calendar_<sem>_phrm_llb` is never requested.
  static List<ScopeTable> tablesFor(String scope, {Set<String> semesterTables = const {}}) {
    final kind = scope.split(':').first;
    final arg = scope.contains(':') ? scope.substring(scope.indexOf(':') + 1) : '';
    switch (kind) {
      case 'user':
        return userTables;
      case 'notifs':
        return notifTables;
      case 'meta':
        return metaTables;
      case 'reference':
        return referenceTables;
      case 'faculty':
        return facultyTables;
      case 'reviews':
        return reviewTables;
      case 'courses':
        final t = 'courses_$arg';
        return semesterTables.contains(t) ? [ScopeTable(t)] : const [];
      case 'calendar':
        return [
          for (final t in ['calendar_$arg', 'calendar_${arg}_phrm_llb'])
            if (semesterTables.contains(t)) ScopeTable(t, style: PullStyle.full),
        ];
    }
    return const [];
  }

  /// Semester key of a row, for the indexed `synced_rows.semester` column.
  static String? semesterOf(String localTable, Map<String, dynamic> row) {
    final m = RegExp(r'^(?:courses|calendar)_([a-z]+\d{4})(?:_phrm_llb)?$').firstMatch(localTable);
    if (m != null) return m.group(1);
    final s = row['semester_code'] ?? row['semester'];
    if (s is String && s.isNotEmpty) return normSemester(s);
    return null;
  }

  /// Local table name for a server table within a scope (only differs for own reviews).
  static String localTableFor(String scope, String serverTable) {
    for (final t in tablesFor(scope, semesterTables: {serverTable})) {
      if (t.server == serverTable) return t.local;
    }
    return serverTable;
  }
}
