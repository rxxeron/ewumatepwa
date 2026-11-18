import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'db/app_database.dart';
import 'sync/outbox.dart';
import 'sync/scope_catalog.dart';

/// One-time import of what v1.1.x cached in Hive, so a student who updates and
/// opens the app OFFLINE still sees their profile, routine and tasks.
///
/// Imported rows are NOT marked as synced: the first online sync does a full
/// pull and replaces them with the server's truth.
Future<void> importLegacyHiveCache(AppDatabase db, {required String? userId}) async {
  const doneKey = 'hive_import_v1';
  try {
    if (await db.getValue(doneKey) != null) return;
    if (userId == null || !Hive.isBoxOpen('profile_box')) {
      await db.setValue(doneKey, 'skipped');
      return;
    }
    final userScope = ScopeCatalog.userScope(userId);

    Map<String, dynamic>? read(String box, String key) {
      if (!Hive.isBoxOpen(box)) return null;
      final raw = Hive.box(box).get(key);
      if (raw is! String) return null;
      try {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        return null;
      }
    }

    await db.transaction(() async {
      // Profile
      final profile = read('profile_box', userId);
      if (profile != null && await db.getRow('profiles', userId) == null) {
        await db.putRow(tbl: 'profiles', rowId: userId, scope: userScope, data: profile);
      }

      // Active semester of the user's track
      final academic = read('dashboard_box', '${userId}_academicState');
      if (academic != null && academic['track'] is String) {
        final row = Map<String, dynamic>.from(academic)..remove('_cache_updated_at');
        final track = row['track'] as String;
        if (await db.getRow('active_semester', track) == null) {
          await db.putRow(tbl: 'active_semester', rowId: track, scope: 'meta', data: row);
        }
      }

      // Weekly grid + tasks from the dashboard payload cache ("<uid>_<sem>_schedule")
      if (Hive.isBoxOpen('dashboard_box')) {
        final box = Hive.box('dashboard_box');
        final re = RegExp('^${RegExp.escape(userId)}_([A-Za-z]+[0-9]{4})_schedule\$');
        for (final key in box.keys.whereType<String>()) {
          final m = re.firstMatch(key);
          if (m == null) continue;
          final payload = read('dashboard_box', key);
          if (payload == null) continue;
          final sem = normSemester(m.group(1));

          final grid = payload['weekly_grid'];
          if (grid is Map && grid.isNotEmpty) {
            final rowId = '$userId|$sem';
            if (await db.getRow('user_semester_states', rowId) == null) {
              await db.putRow(
                tbl: 'user_semester_states',
                rowId: rowId,
                scope: userScope,
                semester: sem,
                data: {'user_id': userId, 'semester_code': sem, 'weekly_grid_cache': grid},
              );
            }
          }
          for (final t in (payload['tasks'] as List? ?? const [])) {
            if (t is! Map || t['id'] == null) continue;
            final task = Map<String, dynamic>.from(t);
            await db.putRow(
              tbl: 'tasks',
              rowId: '${task['id']}',
              scope: userScope,
              semester: ScopeCatalog.semesterOf('tasks', task),
              data: task,
            );
          }
        }
      }
    });

    await _importLegacyQueue(db, userId, userScope);
    await db.setValue(doneKey, DateTime.now().toIso8601String());
  } catch (e) {
    if (kDebugMode) debugPrint('[HiveImport] skipped: $e');
    await db.setValue(doneKey, 'failed');
  }
}

/// v1.1.x offline queue (`sync_queue_box['<uid>_queue']`) -> outbox, so edits made
/// offline before updating are still sent. The old queue is cleared afterwards.
Future<void> _importLegacyQueue(AppDatabase db, String userId, String userScope) async {
  const box = 'sync_queue_box';
  if (!Hive.isBoxOpen(box)) return;
  final raw = Hive.box(box).get('${userId}_queue');
  if (raw is! String) return;
  final List<dynamic> items;
  try {
    items = jsonDecode(raw) as List<dynamic>;
  } catch (_) {
    return;
  }
  final outbox = Outbox(db);

  Future<void> put(String table, Map<String, dynamic> row, String id) =>
      db.putRow(tbl: table, rowId: id, scope: userScope, semester: ScopeCatalog.semesterOf(table, row), data: row);

  for (final it in items.whereType<Map>()) {
    final m = Map<String, dynamic>.from(it);
    final action = '${m['action'] ?? m['type'] ?? ''}';
    try {
      switch (action) {
        case 'create_task':
        case 'update_task':
          final task = Map<String, dynamic>.from(m['task'] as Map);
          final id = '${task['id']}';
          await outbox.write(
            op: OutboxOp.upsert('tasks', task, rowId: id, label: 'Task "${task['title'] ?? ''}" (saved offline)'),
            snapshots: const [],
            localWrite: () => put('tasks', task, id),
          );
        case 'update_task_status':
        case 'update_task_missed':
          final id = '${m['taskId']}';
          final values = action == 'update_task_status'
              ? {'is_completed': m['isCompleted'] == true}
              : {'is_missed': m['isMissed'] == true};
          final before = await db.getRow('tasks', id);
          await outbox.write(
            op: OutboxOp.update('tasks', {'id': id}, values, label: 'Task update (saved offline)'),
            snapshots: const [],
            localWrite: () async {
              if (before != null) await put('tasks', {...before, ...values}, id);
            },
          );
        case 'delete_task':
          final id = '${m['taskId']}';
          await outbox.write(
            op: OutboxOp.delete('tasks', {'id': id}, label: 'Delete task (saved offline)'),
            snapshots: const [],
            localWrite: () async => db.deleteRow('tasks', id),
          );
        case 'save_course_marks':
        case 'progress_update':
          final data = Map<String, dynamic>.from((m['data'] ?? m['payload'] ?? const {}) as Map)
            ..remove('is_new');
          if ('${data['id']}'.startsWith('new_')) data.remove('id');
          final sem = data['semester_code'] ?? m['semesterCode'];
          if (sem != null) data['semester_code'] = normSemester('$sem');
          if (data['course_code'] == null || data['semester_code'] == null) continue;
          data['user_id'] ??= userId;
          await outbox.write(
            op: OutboxOp.upsert('semester_course_marks', data,
                onConflict: 'user_id,semester_code,course_code',
                rowId: data['id']?.toString(),
                label: 'Marks for ${data['course_code']} (saved offline)'),
            snapshots: const [],
            localWrite: () async {},
          );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HiveImport] queue item "$action" skipped: $e');
    }
  }
  await Hive.box(box).delete('${userId}_queue');
}
