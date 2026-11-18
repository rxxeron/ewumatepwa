import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:ewumate/core/models/task.dart';
import 'package:ewumate/core/models/notification.dart';
import 'package:ewumate/core/providers/academic_providers.dart';
import 'package:ewumate/core/repositories/auth_repository.dart';
import 'package:ewumate/core/data/data_providers.dart';
import 'package:ewumate/core/data/db/app_database.dart';
import 'package:ewumate/core/data/repos/local_writer.dart';
import 'package:ewumate/core/data/sync/outbox.dart';
import 'package:ewumate/core/data/sync/scope_catalog.dart';

part 'task_repository.g.dart';

/// Tasks are read from and written to the local database. Every write is
/// applied locally at once and queued for the server (works offline; queued
/// edits are never dropped and survive restarts).
class TaskRepository {
  final AppDatabase _db;
  final Outbox _outbox;

  TaskRepository(this._db, this._outbox);

  LocalWriter _writer(String userId) => LocalWriter(_db, _outbox, userId);

  static Task? _parse(Map<String, dynamic> j) {
    try {
      return Task.fromJson(j);
    } catch (e) {
      if (kDebugMode) debugPrint('[TaskRepository] bad task row ${j['id']}: $e');
      return null;
    }
  }

  static int _byDue(Task a, Task b) {
    final ad = a.dueDate, bd = b.dueDate;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  List<Task> _mine(List<Map<String, dynamic>> rows, String userId) =>
      rows.where((r) => r['user_id'] == userId).map(_parse).whereType<Task>().toList()..sort(_byDue);

  Future<List<Task>> getActiveTasks(String userId, {String? semesterCode}) async {
    final sem = semesterCode == null ? null : normSemester(semesterCode);
    return _mine(await _db.getRows('tasks'), userId)
        .where((t) => !t.isCompleted)
        .where((t) => sem == null || t.semesterCode == null || normSemester(t.semesterCode) == sem)
        .toList();
  }

  /// All of the user's tasks, updating live on every local change or sync.
  Stream<List<Task>> streamUserTasks(String userId, String semesterCode) =>
      _db.watchRows('tasks').map((rows) => _mine(rows, userId));

  Map<String, dynamic> _row(Task task) => task.toJson();

  Future<Task> createTask(String userId, Task task, {String? semesterCode}) async {
    await _writer(userId).upsert('tasks', _row(task), label: 'Add task "${task.title}"');
    return task;
  }

  Future<Task> updateTask(String userId, Task task, {String? semesterCode}) async {
    await _writer(userId).upsert('tasks', _row(task), label: 'Edit task "${task.title}"');
    return task;
  }

  Future<void> updateTaskStatus(String userId, String taskId, bool isCompleted, {String? semesterCode}) =>
      _writer(userId).update('tasks', taskId, {'is_completed': isCompleted},
          label: isCompleted ? 'Complete task' : 'Reopen task');

  Future<void> updateTaskMissedStatus(String userId, String taskId, bool isMissed, {String? semesterCode}) =>
      _writer(userId).update('tasks', taskId, {'is_missed': isMissed}, label: 'Mark task missed');

  Future<void> deleteTask(String userId, String taskId, {String? semesterCode}) =>
      _writer(userId).delete('tasks', taskId, label: 'Delete task');

  Stream<List<Notification>> streamNotifications(String userId) {
    return _db.watchRows('notifications').map((rows) {
      final list = <Notification>[];
      for (final r in rows) {
        if (r['user_id'] != userId) continue;
        try {
          list.add(Notification.fromJson(r));
        } catch (_) {}
      }
      list.sort((a, b) => (b.triggerAt ?? b.createdAt ?? DateTime(0)).compareTo(a.triggerAt ?? a.createdAt ?? DateTime(0)));
      return list;
    });
  }
}

@riverpod
TaskRepository taskRepository(Ref ref) {
  return TaskRepository(ref.watch(appDatabaseProvider), ref.watch(outboxProvider));
}

@riverpod
Future<List<Task>> activeTasksConfig(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final semCode = await ref.watch(currentSemesterCodeProvider.future);
  return ref.watch(taskRepositoryProvider).getActiveTasks(user.id, semesterCode: semCode);
}

@Riverpod(keepAlive: true)
Stream<List<Task>> allTasksStream(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(taskRepositoryProvider).streamUserTasks(user.id, '');
}

@Riverpod(keepAlive: true)
Stream<List<Notification>> userNotifications(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(taskRepositoryProvider).streamNotifications(user.id);
}
