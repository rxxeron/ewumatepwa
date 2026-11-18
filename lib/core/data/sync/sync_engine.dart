import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import 'outbox.dart';
import 'scope_catalog.dart';
import 'sync_api.dart';

class SyncReport {
  final DateTime finishedAt;
  final List<String> pulledScopes;
  final Map<String, String> errors;
  final bool offline;
  final int outboxSent;
  final int outboxRejected;

  const SyncReport({
    required this.finishedAt,
    this.pulledScopes = const [],
    this.errors = const {},
    this.offline = false,
    this.outboxSent = 0,
    this.outboxRejected = 0,
  });

  bool get ok => !offline && errors.isEmpty;
}

/// Picks which semester scopes (`courses:<sem>`, `calendar:<sem>`) the device keeps,
/// from the already-synced local meta + profile. Injected so tests can control it.
typedef SemesterPicker = Future<Set<String>> Function(AppDatabase db, String userId);

/// Pulls server changes into [AppDatabase] and pushes the [Outbox].
///
/// One run at a time: a call while running returns the running future and
/// schedules exactly one more run afterwards (so a trigger is never lost).
class SyncEngine {
  final AppDatabase db;
  final SyncApi api;
  final Outbox outbox;
  final OutboxExecutor executor;
  final String userId;
  final SemesterPicker pickSemesters;
  final int pageSize;

  SyncEngine({
    required this.db,
    required this.api,
    required this.outbox,
    required this.executor,
    required this.userId,
    SemesterPicker? pickSemesters,
    this.pageSize = 1000,
  }) : pickSemesters = pickSemesters ?? defaultSemesterPicker;

  Future<SyncReport>? _running;
  bool _again = false;
  bool _againForce = false;

  final _reports = StreamController<SyncReport>.broadcast();
  Stream<SyncReport> get reports => _reports.stream;

  final _busy = StreamController<bool>.broadcast();
  Stream<bool> get busy => _busy.stream;
  bool get isRunning => _running != null;

  List<String> get fixedScopes => [
        'meta',
        ScopeCatalog.userScope(userId),
        ScopeCatalog.notifsScope(userId),
        'reference',
        'faculty',
        'reviews',
      ];

  Future<SyncReport> sync({bool force = false}) {
    final running = _running;
    if (running != null) {
      _again = true;
      _againForce |= force;
      return running;
    }
    final f = _loop(force);
    _running = f;
    _busy.add(true);
    return f.whenComplete(() {
      _running = null;
      _busy.add(false);
    });
  }

  Future<SyncReport> _loop(bool force) async {
    var report = await _runOnce(force);
    while (_again) {
      final f = _againForce;
      _again = false;
      _againForce = false;
      report = await _runOnce(f);
    }
    return report;
  }

  Future<SyncReport> _runOnce(bool force) async {
    var sent = 0;
    var rejected = 0;
    try {
      // 1. Push first, so the pull below already reflects our own writes.
      final flush = await outbox.flush(executor);
      sent = flush.sent;
      rejected = flush.rejected;
      if (flush.stoppedEarly) {
        final r = SyncReport(finishedAt: DateTime.now(), offline: true, outboxSent: sent, outboxRejected: rejected);
        _reports.add(r);
        return r;
      }

      // 2. What changed?
      final check = await api.check();

      final pulled = <String>[];
      final errors = <String, String>{};

      Future<void> handle(String scope) async {
        try {
          if (await _pullScopeIfChanged(scope, check, force)) pulled.add(scope);
        } catch (e) {
          if (isTransientNetworkError(e)) rethrow;
          errors[scope] = '$e';
          await _setScopeError(scope, '$e');
          if (kDebugMode) debugPrint('[Sync] scope $scope failed: $e');
        }
      }

      // meta first: the semester list depends on it.
      for (final s in fixedScopes) {
        await handle(s);
      }
      for (final sem in await pickSemesters(db, userId)) {
        await handle(ScopeCatalog.coursesScope(sem));
        await handle(ScopeCatalog.calendarScope(sem));
      }

      final r = SyncReport(
        finishedAt: DateTime.now(),
        pulledScopes: pulled,
        errors: errors,
        outboxSent: sent,
        outboxRejected: rejected,
      );
      _reports.add(r);
      return r;
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] run failed: $e');
      final r = SyncReport(
        finishedAt: DateTime.now(),
        offline: isTransientNetworkError(e),
        errors: isTransientNetworkError(e) ? const {} : {'*': '$e'},
        outboxSent: sent,
        outboxRejected: rejected,
      );
      _reports.add(r);
      return r;
    }
  }

  /// Returns true when the scope was pulled.
  Future<bool> _pullScopeIfChanged(String scope, SyncCheck check, bool force) async {
    final local = await (db.select(db.syncScopes)..where((t) => t.scope.equals(scope))).getSingleOrNull();
    final serverVersion = check.versions[scope];
    final upToDate = local?.cursor != null && local!.version == serverVersion && local.lastError == null;
    if (upToDate && !force) return false;

    final tables = ScopeCatalog.tablesFor(scope, semesterTables: check.semesterTables);
    if (tables.isEmpty) {
      // e.g. a semester without a calendar table yet: remember the check so we do not ask again.
      await _saveScope(scope, serverVersion, check.cursor);
      return false;
    }

    String? since = local?.cursor;
    final tombstones = <(String, String)>[];
    if (since != null && tables.any((t) => t.style == PullStyle.delta)) {
      final ts = await api.tombstones(scope, since);
      if (ts.resync) {
        since = null; // cursor older than the purge horizon: full re-pull
      } else {
        tombstones.addAll(ts.items);
      }
    }

    // Download everything first; apply in one transaction so a half-finished pull never shows.
    final pulled = <ScopeTable, List<Map<String, dynamic>>>{};
    for (final t in tables) {
      final full = t.style == PullStyle.full || since == null;
      final rows = <Map<String, dynamic>>[];
      String? after;
      do {
        final page = await api.pull(scope, t.server, since: full ? null : since, after: after, limit: pageSize);
        rows.addAll(page.rows);
        after = page.next;
      } while (after != null);
      pulled[t] = rows;
    }

    final protected = await outbox.protectedKeys();

    await db.transaction(() async {
      for (final (serverTable, rowId) in tombstones) {
        final localTbl = ScopeCatalog.localTableFor(scope, serverTable);
        if (protected.contains(Outbox.key(localTbl, rowId))) continue;
        await (db.delete(db.syncedRows)
              ..where((r) => r.tbl.equals(localTbl) & r.rowId.equals(rowId) & r.scope.equals(scope)))
            .go();
      }

      for (final entry in pulled.entries) {
        final t = entry.key;
        final rows = entry.value;
        final full = t.style == PullStyle.full || since == null;

        if (full) {
          // Replace: drop local rows the server no longer has (keeping unsynced local edits).
          final keep = {for (final r in rows) t.rowIdOf(r)};
          final existing = await (db.selectOnly(db.syncedRows)
                ..addColumns([db.syncedRows.rowId])
                ..where(db.syncedRows.tbl.equals(t.local) & db.syncedRows.scope.equals(scope)))
              .map((r) => r.read(db.syncedRows.rowId)!)
              .get();
          for (final id in existing) {
            if (!keep.contains(id) && !protected.contains(Outbox.key(t.local, id))) {
              await (db.delete(db.syncedRows)..where((r) => r.tbl.equals(t.local) & r.rowId.equals(id))).go();
            }
          }
        }

        await db.batch((b) {
          for (final row in rows) {
            final id = t.rowIdOf(row);
            if (protected.contains(Outbox.key(t.local, id))) continue;
            b.insert(
              db.syncedRows,
              SyncedRowsCompanion.insert(
                tbl: t.local,
                rowId: id,
                scope: scope,
                semester: Value(ScopeCatalog.semesterOf(t.local, row)),
                data: jsonEncode(row),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
      }

      await _saveScope(scope, serverVersion, check.cursor);
    });
    return true;
  }

  Future<void> _saveScope(String scope, int? version, String cursor) =>
      db.into(db.syncScopes).insertOnConflictUpdate(SyncScopesCompanion.insert(
            scope: scope,
            version: Value(version),
            cursor: Value(cursor),
            lastSyncedAt: Value(DateTime.now()),
            lastError: const Value(null),
          ));

  Future<void> _setScopeError(String scope, String error) async {
    final existing = await (db.select(db.syncScopes)..where((t) => t.scope.equals(scope))).getSingleOrNull();
    if (existing == null) {
      await db.into(db.syncScopes).insert(SyncScopesCompanion.insert(scope: scope, lastError: Value(error)));
    } else {
      await (db.update(db.syncScopes)..where((t) => t.scope.equals(scope)))
          .write(SyncScopesCompanion(lastError: Value(error)));
    }
  }

  Future<void> dispose() async {
    await _reports.close();
    await _busy.close();
  }

  /// Current + next semester of the user's track (from local `active_semester` and profile).
  static Future<Set<String>> defaultSemesterPicker(AppDatabase db, String userId) async {
    final profile = await db.getRow('profiles', userId);
    final track = (profile?['track'] as String?) ?? 'tri_semester';
    final rows = await db.getRows('active_semester');
    final mine = rows.where((r) => r['track'] == track).toList();
    final pick = mine.isNotEmpty ? mine : rows;
    return {
      for (final r in pick)
        for (final c in [r['current_semester_code'], r['next_semester_code']])
          if (c is String && c.trim().isNotEmpty) normSemester(c),
    };
  }
}
