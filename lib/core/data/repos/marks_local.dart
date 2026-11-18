import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../utils/course_utils.dart';
import '../db/app_database.dart';
import '../sync/outbox.dart';
import '../sync/scope_catalog.dart';
import 'local_writer.dart';

/// The one implementation of "a semester's course marks" (replaces the two
/// diverging Hive-cached versions). Reads local rows; writes go through the outbox.
class MarksLocal {
  final AppDatabase db;
  final Outbox outbox;
  MarksLocal(this.db, this.outbox);

  static const table = 'semester_course_marks';

  Future<List<Map<String, dynamic>>> _enrolled(String userId, String sem) async =>
      (await db.getRows('enrollments', semester: sem)).where((e) => e['user_id'] == userId).toList();

  Future<List<Map<String, dynamic>>> _marks(String userId, String sem) async =>
      (await db.getRows(table, semester: sem)).where((m) => m['user_id'] == userId).toList();

  /// Every enrolled course of the semester with its marks row (a `new_<code>` stub
  /// when none exists yet), plus marks rows of courses no longer enrolled.
  Future<List<Map<String, dynamic>>> semesterRows(String userId, String semesterCode) async {
    final sem = normSemester(semesterCode);
    final marks = await _marks(userId, sem);
    final result = <Map<String, dynamic>>[];

    for (final e in await _enrolled(userId, sem)) {
      final code = '${e['course_code'] ?? ''}';
      if (code.isEmpty) continue;
      final existing = marks.where((m) => CourseUtils.areEquivalent('${m['course_code']}', code)).firstOrNull;
      result.add(existing ??
          {
            'id': 'new_${CourseUtils.normalize(code)}',
            'user_id': userId,
            'semester_code': sem,
            'course_code': code,
            'is_new': true,
          });
    }
    for (final m in marks) {
      if (!result.any((r) => CourseUtils.areEquivalent('${r['course_code']}', '${m['course_code']}'))) {
        result.add(m);
      }
    }
    return result;
  }

  /// Watches the inputs of [semesterRows] (marks + enrollments) and re-emits on any change.
  Stream<List<Map<String, dynamic>>> watchSemesterRows(String userId, String semesterCode) async* {
    final sem = normSemester(semesterCode);
    yield await semesterRows(userId, semesterCode);
    final q = db.select(db.syncedRows)
      ..where((t) => t.semester.equals(sem) & (t.tbl.equals(table) | t.tbl.equals('enrollments')));
    await for (final _ in q.watch().skip(1)) {
      yield await semesterRows(userId, semesterCode);
    }
  }

  /// Upsert a course's marks. Only the given columns change on the server
  /// (PostgREST upsert), so e.g. a write without `marks_data` never wipes attendance.
  Future<Map<String, dynamic>> save(String userId, String semesterCode, Map<String, dynamic> data,
      {String Function(String code)? normalizeCode}) async {
    final sem = normSemester(semesterCode);
    final row = Map<String, dynamic>.from(data)..remove('is_new');
    final code = '${row['course_code'] ?? ''}';
    row['course_code'] = (normalizeCode ?? CourseUtils.normalize)(code);
    row['semester_code'] = CourseUtils.cleanSemester(semesterCode);
    row['user_id'] = userId;

    // Keep the existing row id (same course, any spelling); new rows get a client id.
    final existing = (await _marks(userId, sem))
        .where((m) => CourseUtils.areEquivalent('${m['course_code']}', code))
        .firstOrNull;
    final id = '${row['id'] ?? ''}';
    if (existing != null) {
      row['id'] = existing['id'];
    } else if (id.isEmpty || id.startsWith('new_')) {
      row['id'] = const Uuid().v4();
    }

    await LocalWriter(db, outbox, userId).upsert(
      table,
      row,
      onConflict: 'user_id,semester_code,course_code',
      label: 'Marks for ${row['course_code']}',
    );
    return {...?existing, ...row};
  }
}
