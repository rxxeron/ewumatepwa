import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/data_providers.dart';
import '../data/db/app_database.dart';
import '../data/sync/scope_catalog.dart';
import '../models/course_metadata.dart';
import '../models/course_section.dart';
import '../providers/supabase_provider.dart';
import '../utils/course_utils.dart';

part 'course_repository.g.dart';

/// Course catalog and sections. The current/next semester sections and the
/// catalog are synced to the local database, so browsing and search work
/// offline. Semesters the device does not keep (older ones) are read from the
/// server on demand, as before.
class CourseRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;

  CourseRepository(this._supabase, this._db);

  static List<CourseMetadata> _parseMeta(Iterable<Map<String, dynamic>> rows) {
    final out = <CourseMetadata>[];
    for (final r in rows) {
      try {
        out.add(CourseMetadata.fromJson(r));
      } catch (_) {}
    }
    out.sort((a, b) => a.code.compareTo(b.code));
    return out;
  }

  Future<List<CourseMetadata>> getAllCourses({int offset = 0, int limit = 3000}) async {
    var list = _parseMeta(await _db.getRows('course_metadata'));
    if (list.isEmpty) list = await _fetchAllRemote(limit);
    CourseUtils.registerTitles({for (final c in list) c.code: c.name});
    return list.skip(offset).take(limit).toList();
  }

  /// First launch only (catalog not synced yet).
  Future<List<CourseMetadata>> _fetchAllRemote(int limit) async {
    final all = <CourseMetadata>[];
    try {
      var offset = 0;
      const page = 1000;
      while (all.length < limit) {
        final data = await _supabase
            .from('course_metadata')
            .select()
            .order('code', ascending: true)
            .range(offset, offset + page - 1);
        final list = data as List;
        if (list.isEmpty) break;
        all.addAll(_parseMeta(list.map((e) => Map<String, dynamic>.from(e as Map))));
        offset += list.length;
        if (list.length < page) break;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CourseRepository] catalog fetch failed: $e');
    }
    return all;
  }

  /// Offline search: code prefix/contains first, then name.
  Future<List<CourseMetadata>> searchCourses(String query) async {
    final all = await getAllCourses();
    if (query.isEmpty) return all;
    final q = query.replaceAll(' ', '').toUpperCase();
    final byCode = all.where((c) => c.code.replaceAll(' ', '').toUpperCase().contains(q)).toList()
      ..sort((a, b) {
        final ap = a.code.toUpperCase().startsWith(q) ? 0 : 1;
        final bp = b.code.toUpperCase().startsWith(q) ? 0 : 1;
        return ap != bp ? ap - bp : a.code.compareTo(b.code);
      });
    if (byCode.isNotEmpty) return byCode;
    final lower = query.toLowerCase();
    return all.where((c) => c.name.toLowerCase().contains(lower)).toList();
  }

  Future<List<Map<String, dynamic>>> _semesterRows(String semesterCode) async {
    final sem = normSemester(semesterCode);
    return _db.getRows('courses_$sem');
  }

  Future<List<CourseSection>> getCourseSections(
    String semesterCode,
    String courseCode, {
    String? cycleType,
  }) async {
    final sem = normSemester(semesterCode);
    final base = courseCode.replaceAll(' ', '').toUpperCase();
    String alt = '';
    final reg3 = RegExp(r'^([A-Z]{2,4})(\d{3})$');
    final reg4 = RegExp(r'^([A-Z]{2,4})7(\d{3})$');
    if (reg3.hasMatch(base)) {
      final m = reg3.firstMatch(base)!;
      alt = '${m.group(1)}7${m.group(2)}';
    } else if (reg4.hasMatch(base)) {
      final m = reg4.firstMatch(base)!;
      alt = '${m.group(1)}${m.group(2)}';
    }

    final local = await _semesterRows(sem);
    if (local.isNotEmpty) {
      final matched = local.where((e) {
        final c = '${e['course_code'] ?? ''}'.toUpperCase().replaceAll(' ', '');
        return c == base || (alt.isNotEmpty && c == alt) || c.contains(base);
      });
      return matched.map((e) => _mapToCourseSection(Map<String, dynamic>.from(e))).toList();
    }

    // Semester not kept on this device: read from the server (online only).
    try {
      final fuzzyBase = base.split('').join('%');
      final orClause = alt.isNotEmpty
          ? 'course_code.ilike.%$fuzzyBase%,course_code.ilike.%${alt.split('').join('%')}%'
          : 'course_code.ilike.%$fuzzyBase%';
      final data = await _supabase.from('courses_$sem').select().or(orClause);
      return (data as List).map((e) => _mapToCourseSection(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  CourseSection _mapToCourseSection(Map<String, dynamic> map) {
    map['id'] = map['id']?.toString() ?? map['course_code'];
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
  }

  static List<CourseMetadata> _uniqueCourses(Iterable<Map<String, dynamic>> rows) {
    final unique = <String, CourseMetadata>{};
    for (final e in rows) {
      final code = '${e['course_code'] ?? ''}';
      if (code.isEmpty || unique.containsKey(code)) continue;
      unique[code] = CourseMetadata(
        code: code,
        name: '${e['course_name'] ?? e['name'] ?? 'Unknown'}',
        creditVal: (e['credit_val'] as num?)?.toDouble() ?? 3.0,
      );
    }
    return unique.values.toList()..sort((a, b) => a.code.compareTo(b.code));
  }

  Future<List<CourseMetadata>> getSemesterCourses(String semesterCode) async {
    final local = await _semesterRows(semesterCode);
    final list = local.isNotEmpty ? _uniqueCourses(local) : await _fetchSemesterRemote(semesterCode);
    CourseUtils.registerTitles({for (final c in list) c.code: c.name});
    return list;
  }

  Future<List<CourseMetadata>> _fetchSemesterRemote(String semesterCode) async {
    final table = 'courses_${normSemester(semesterCode)}';
    final rows = <Map<String, dynamic>>[];
    try {
      var offset = 0;
      const page = 1000;
      while (offset < 20000) {
        final res = await _supabase
            .from(table)
            .select('course_code, course_name, credit_val')
            .order('course_code', ascending: true)
            .range(offset, offset + page - 1);
        final list = res as List;
        if (list.isEmpty) break;
        rows.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        offset += list.length;
        if (list.length < page) break;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CourseRepository] $table fetch failed: $e');
    }
    return _uniqueCourses(rows);
  }
}

@riverpod
CourseRepository courseRepository(Ref ref) {
  return CourseRepository(ref.watch(supabaseClientProvider), ref.watch(appDatabaseProvider));
}

@riverpod
Future<List<CourseMetadata>> allCourses(Ref ref) {
  return ref.watch(courseRepositoryProvider).getAllCourses(limit: 3000);
}

@riverpod
Future<List<CourseMetadata>> semesterCourses(Ref ref, String semesterCode) {
  return ref.watch(courseRepositoryProvider).getSemesterCourses(semesterCode);
}

@riverpod
Future<List<CourseSection>> courseSections(
  Ref ref, {
  required String semesterCode,
  required String courseCode,
}) {
  return ref.watch(courseRepositoryProvider).getCourseSections(semesterCode, courseCode);
}
