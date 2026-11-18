import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ewumate/core/repositories/progress_repository.dart';
import 'package:ewumate/core/models/academic_state.dart';
import 'package:ewumate/core/utils/course_utils.dart';
import 'package:ewumate/core/data/data_providers.dart';
import 'package:ewumate/core/data/repos/local_writer.dart';
import 'package:ewumate/features/auth/auth_providers.dart';

final programDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, programCode) async {
  final rows = await ref.watch(localRowsProvider(('programs', null)).future);
  final local = rows.where((r) => '${r['program_code']}'.toUpperCase() == programCode.toUpperCase()).firstOrNull;
  if (local != null) return local;
  // Not synced yet (first launch): fall back to the network once.
  return ref.watch(progressRepositoryProvider).getProgramDetails(programCode);
});

/// The single source of "which semester is it" for the signed-in user:
/// local `active_semester` row of the user's track. Replaces the separate
/// resolvers and hard-coded fallbacks scattered across features.
final academicStateProvider = FutureProvider<AcademicState?>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return null;
  final profile = await ref.watch(profileProvider.future);
  final rows = await ref.watch(localRowsProvider(('active_semester', null)).future);
  if (rows.isEmpty) return null;

  final track = CourseUtils.normalizeTrack(profile?.track ?? profile?.semesterType);
  final row = rows.where((r) => r['track'] == track).firstOrNull ?? rows.first;
  return AcademicState.fromJson({
    ...row,
    'track': track,
    'current_semester_code': row['current_semester_code'] ?? '',
    'next_semester_code': row['next_semester_code'] ?? '',
  });
});

final currentSemesterCodeProvider = FutureProvider<String?>((ref) async {
  final s = await ref.watch(academicStateProvider.future);
  final code = s?.currentSemesterCode;
  return (code == null || code.isEmpty) ? null : code;
});

final nextSemesterCodeProvider = FutureProvider<String?>((ref) async {
  final s = await ref.watch(academicStateProvider.future);
  final code = s?.nextSemesterCode;
  return (code == null || code.isEmpty) ? null : code;
});

final semestersProvider = FutureProvider<List<dynamic>>((ref) async {
  final rows = await ref.watch(localRowsProvider(('semesters', null)).future);
  final titles = rows.map((e) => e['title'].toString()).toSet().toList();
  return titles.map((t) => (title: t)).toList();
});

final facultySnapshotsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.watch(localRowsProvider(('app_config', null)).future);
  final value = rows.where((r) => r['key'] == 'faculty_snapshots').firstOrNull?['value'];
  if (value is Map && value['snapshots'] is List) {
    return List<Map<String, dynamic>>.from(value['snapshots'] as List);
  }
  return [];
});
