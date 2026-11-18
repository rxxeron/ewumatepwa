import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/data_providers.dart';
import '../data/db/app_database.dart';
import '../data/sync/scope_catalog.dart';
import '../models/faculty.dart';
import '../models/course_section.dart';
import '../providers/supabase_provider.dart';

part 'faculty_repository.g.dart';

/// Faculty directory from the local database (scope `faculty`), searchable offline.
class FacultyRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;

  FacultyRepository(this._supabase, this._db);

  static const _columns =
      'id, full_name, short_name, email, designation_name, photo_url, office_room, department, department_name';

  static List<Faculty> _parse(Iterable<Map<String, dynamic>> rows) {
    final out = <Faculty>[];
    for (final r in rows) {
      try {
        out.add(Faculty.fromMap(r));
      } catch (_) {}
    }
    out.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return out;
  }

  Future<List<Faculty>> getAllFaculty() async {
    final local = await _db.getRows('faculty_master');
    if (local.isNotEmpty) return _parse(local);
    // First launch, directory not synced yet.
    try {
      final data = await _supabase.from('faculty_master').select(_columns).order('full_name', ascending: true);
      return _parse((data as List).map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to fetch faculty directory: $e');
      return [];
    }
  }

  Future<List<Faculty>> searchFaculty(String query) async {
    final all = await getAllFaculty();
    if (query.isEmpty) return all;
    final q = query.toLowerCase();
    return all
        .where((f) =>
            f.fullName.toLowerCase().contains(q) ||
            f.shortName.toLowerCase().contains(q) ||
            (f.email ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<List<CourseSection>> getFacultySections(String initials, String semesterCode) async {
    final sem = normSemester(semesterCode);
    final wanted = initials.trim().toUpperCase();
    List<Map<String, dynamic>> rows = (await _db.getRows('courses_$sem'))
        .where((r) => '${r['faculty_initials'] ?? ''}'.trim().toUpperCase() == wanted)
        .toList();

    if (rows.isEmpty && (await _db.getRows('courses_$sem')).isEmpty) {
      // Semester not kept on this device: online lookup as before.
      try {
        final data = await _supabase.from('courses_$sem').select().ilike('faculty_initials', initials);
        rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to fetch faculty sections: $e');
        return [];
      }
    }

    return rows.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['id'] = map['id']?.toString() ?? e['course_code'];
      map['code'] = map['course_code'] ?? map['code'];
      map['section'] = map['section_number'] ?? map['section'];
      map['sessions'] = (map['schedule_data'] as List? ?? []).map((s) {
        final sessionMap = Map<String, dynamic>.from(s);
        sessionMap['start_time'] = sessionMap['startTime'] ?? sessionMap['start_time'];
        sessionMap['end_time'] = sessionMap['endTime'] ?? sessionMap['end_time'];
        return sessionMap;
      }).toList();
      map['capacity'] = map['capacity']?.toString() ?? '0/0';
      map['credits'] = map['credit_val']?.toString() ?? '3.0';
      return CourseSection.fromJson(map);
    }).toList();
  }
}

@riverpod
FacultyRepository facultyRepository(Ref ref) {
  return FacultyRepository(ref.watch(supabaseClientProvider), ref.watch(appDatabaseProvider));
}

@riverpod
Future<List<Faculty>> allFaculty(Ref ref) {
  return ref.watch(facultyRepositoryProvider).getAllFaculty();
}

@riverpod
Future<List<CourseSection>> facultySections(
  Ref ref, {
  required String initials,
  required String semesterCode,
}) {
  return ref.watch(facultyRepositoryProvider).getFacultySections(initials, semesterCode);
}
