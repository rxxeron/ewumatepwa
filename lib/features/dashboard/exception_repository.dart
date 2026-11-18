import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/data/db/app_database.dart';
import '../../core/data/repos/local_writer.dart';
import '../../core/data/sync/outbox.dart';

/// Class cancellations, makeup and manual classes. Local-first: a change shows
/// immediately (also offline) and is queued for the server; a server rejection
/// is rolled back and listed under "Sync issues" instead of silently vanishing.
class ExceptionRepository {
  final AppDatabase _db;
  ExceptionRepository([AppDatabase? db]) : _db = db ?? AppDatabase.main;

  static const _table = 'schedule_exceptions';

  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  LocalWriter? get _writer {
    final uid = _uid;
    return uid == null ? null : LocalWriter(_db, Outbox(_db), uid);
  }

  /// Kept for API compatibility: local reads are always current.
  void invalidateCache() {}

  /// All of the user's exceptions.
  Future<List<Map<String, dynamic>>> fetchExceptions({bool forceRefresh = false}) async {
    final uid = _uid;
    if (uid == null) return [];
    return (await _db.getRows(_table)).where((r) => r['user_id'] == uid).toList();
  }

  Future<void> _insert(Map<String, dynamic> row, String label) async {
    final w = _writer;
    if (w == null) return;
    await w.upsert(_table, {'id': const Uuid().v4(), 'user_id': w.userId, ...row}, label: label);
  }

  Future<void> addCancellation(String date, String courseCode, {bool pendingMakeup = false}) => _insert({
        'type': 'cancel',
        'date': date,
        'course_code': courseCode,
        'metadata': {'pendingMakeup': pendingMakeup},
      }, 'Cancel $courseCode on $date');

  Future<void> addMakeupClass({
    required String date,
    required String courseCode,
    required String courseName,
    required String startTime,
    required String endTime,
    required String room,
    String? faculty,
  }) =>
      _insert({
        'type': 'makeup',
        'date': date,
        'course_code': courseCode,
        'course_name': courseName,
        'start_time': startTime,
        'end_time': endTime,
        'room': room,
        'faculty': faculty,
        'metadata': <String, dynamic>{},
      }, 'Makeup class $courseCode on $date');

  Future<void> addManualClass({
    required String date,
    required String courseCode,
    required String courseName,
    required String startTime,
    required String endTime,
    required String room,
    String? faculty,
  }) =>
      _insert({
        'type': 'manual',
        'date': date,
        'course_code': courseCode,
        'course_name': courseName,
        'start_time': startTime,
        'end_time': endTime,
        'room': room,
        'faculty': faculty,
        'metadata': <String, dynamic>{},
      }, 'Class $courseCode on $date');

  /// Mark a pending makeup as resolved (called when the makeup is actually scheduled).
  Future<void> resolvePendingMakeup(String originalExceptionId) async {
    await _writer?.update(_table, originalExceptionId, {
      'metadata': {'pendingMakeup': false}
    }, label: 'Resolve makeup');
  }

  /// Remove an exception completely (undo cancel).
  Future<void> removeException(String id) async {
    await _writer?.delete(_table, id, label: 'Undo class change');
  }

  Future<String?> findExceptionId(String date, String courseCode, String type) async {
    final rows = await fetchExceptions();
    return rows
        .where((r) => r['date'] == date && r['course_code'] == courseCode && r['type'] == type)
        .map((r) => r['id']?.toString())
        .firstOrNull;
  }
}
