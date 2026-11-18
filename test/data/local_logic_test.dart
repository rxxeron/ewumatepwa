import 'package:ewumate/core/data/repos/weekly_grid.dart';
import 'package:ewumate/core/data/sync/scope_catalog.dart';
import 'package:ewumate/core/data/sync/sync_status.dart';
import 'package:ewumate/features/auth/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildWeeklyGrid (port of sync-schedule generateTemplate)', () {
    final sections = [
      {
        'course_code': 'CSE101',
        'course_name': 'Intro',
        'schedule_data': [
          {'day': 'MW', 'startTime': '8:30 AM', 'endTime': '10:00 AM', 'room': '221', 'type': 'Theory'},
          {'day': 'R', 'start_time': '1:00 PM', 'end_time': '3:00 PM', 'type': 'Lab', 'faculty_initials': 'ABC'},
        ],
      },
    ];

    test('places sessions on EWU day codes (R = Thursday) with both key spellings', () {
      final g = buildWeeklyGrid(sections);
      expect(g.keys, containsAll(['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']));
      expect(g['Monday']!.single['startTime'], '8:30 AM');
      expect(g['Wednesday']!.single['room'], '221');
      expect(g['Thursday']!.single['endTime'], '3:00 PM');
      expect(g['Thursday']!.single['type'], 'Lab');
      expect(g['Thursday']!.single['faculty'], 'ABC');
      expect(g['Tuesday'], isEmpty);
    });

    test('master programs are always Theory', () {
      expect(buildWeeklyGrid(sections, programCode: 'mba')['Thursday']!.single['type'], 'Theory');
    });

    test('missing values default to TBA', () {
      final g = buildWeeklyGrid([
        {'course_code': 'X', 'schedule_data': [{'day': 'S'}]},
      ]);
      expect(g['Sunday']!.single['startTime'], 'TBA');
      expect(g['Sunday']!.single['room'], 'TBA');
    });
  });

  group('computeRequiresGradeEntry', () {
    final active = [
      {'track': 'tri_semester', 'current_semester_code': 'Fall 2026', 'grade_submission_start': '2026-12-20'},
    ];

    test('unsubmitted course from a past semester blocks', () {
      expect(
        computeRequiresGradeEntry(
          track: 'tri_semester',
          activeSemesters: active,
          enrollments: [
            {'status': 'enrolled', 'grade': null, 'semester_code': 'summer2026'},
          ],
          now: DateTime(2026, 11, 18),
        ),
        isTrue,
      );
    });

    test('current semester in any spelling does not block before submission opens', () {
      expect(
        computeRequiresGradeEntry(
          track: 'tri_semester',
          activeSemesters: active,
          enrollments: [
            {'status': 'enrolled', 'grade': null, 'semester_code': 'fall2026'},
          ],
          now: DateTime(2026, 11, 18),
        ),
        isFalse,
      );
    });

    test('current semester blocks one day after submission opens', () {
      expect(
        computeRequiresGradeEntry(
          track: 'tri_semester',
          activeSemesters: active,
          enrollments: [
            {'status': 'enrolled', 'grade': null, 'semester_code': 'FALL_2026'},
          ],
          now: DateTime(2026, 12, 22),
        ),
        isTrue,
      );
    });

    test('graded or other-track rows never block', () {
      expect(
        computeRequiresGradeEntry(
          track: 'bi_semester',
          activeSemesters: active,
          enrollments: [
            {'status': 'enrolled', 'grade': null, 'semester_code': 'summer2026'},
          ],
          now: DateTime(2026, 12, 22),
        ),
        isFalse,
      );
    });
  });

  test('normSemester canonical key', () {
    expect(normSemester('2026 Fall'), 'fall2026');
    expect(normSemester(' Spring-2027 '), 'spring2027');
    expect(ScopeCatalog.semesterOf('calendar_fall2026_phrm_llb', const {}), 'fall2026');
    expect(ScopeCatalog.semesterOf('tasks', const {'semester_code': 'Summer 2026'}), 'summer2026');
    expect(ScopeCatalog.tablesFor('calendar:fall2026', semesterTables: {'calendar_fall2026'}).map((t) => t.server),
        ['calendar_fall2026']);
  });

  test('formatAgo', () {
    final now = DateTime(2026, 11, 18, 12);
    expect(formatAgo(null), 'never');
    expect(formatAgo(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
    expect(formatAgo(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
    expect(formatAgo(now.subtract(const Duration(days: 2)), now: now), '2 d ago');
  });
}
