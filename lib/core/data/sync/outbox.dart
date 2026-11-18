import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import 'sync_api.dart';

/// A local row affected by an op, captured *before* the local write so a server
/// rejection can put it back. `data == null` means "the row did not exist".
class RowSnapshot {
  final String tbl;
  final String rowId;
  final String scope;
  final String? semester;
  final Map<String, dynamic>? data;

  const RowSnapshot({required this.tbl, required this.rowId, required this.scope, this.semester, this.data});

  Map<String, dynamic> toJson() => {'tbl': tbl, 'rowId': rowId, 'scope': scope, 'semester': semester, 'data': data};

  factory RowSnapshot.fromJson(Map<String, dynamic> j) => RowSnapshot(
        tbl: j['tbl'] as String,
        rowId: j['rowId'] as String,
        scope: j['scope'] as String,
        semester: j['semester'] as String?,
        data: (j['data'] as Map?)?.cast<String, dynamic>(),
      );
}

/// What a queued write does on the server.
///   upsert: {table, row, onConflict?}
///   update: {table, match: {col: value}, values}
///   delete: {table, match: {col: value}}
///   rpc:    {fn, params}   (result {"status":"rejected","reason":..} counts as a rejection)
class OutboxOp {
  final String kind;
  final Map<String, dynamic> payload;
  final String? tbl;
  final String? rowId;
  final String? label;

  const OutboxOp._(this.kind, this.payload, {this.tbl, this.rowId, this.label});

  factory OutboxOp.upsert(String table, Map<String, dynamic> row,
          {String? onConflict, String? localTbl, String? rowId, String? label}) =>
      OutboxOp._('upsert', {'table': table, 'row': row, 'onConflict': onConflict},
          tbl: localTbl ?? table, rowId: rowId ?? row['id']?.toString(), label: label);

  factory OutboxOp.update(String table, Map<String, dynamic> match, Map<String, dynamic> values,
          {String? localTbl, String? rowId, String? label}) =>
      OutboxOp._('update', {'table': table, 'match': match, 'values': values},
          tbl: localTbl ?? table, rowId: rowId ?? match['id']?.toString(), label: label);

  factory OutboxOp.delete(String table, Map<String, dynamic> match, {String? localTbl, String? rowId, String? label}) =>
      OutboxOp._('delete', {'table': table, 'match': match},
          tbl: localTbl ?? table, rowId: rowId ?? match['id']?.toString(), label: label);

  factory OutboxOp.rpc(String fn, Map<String, dynamic> params, {String? tbl, String? rowId, String? label}) =>
      OutboxOp._('rpc', {'fn': fn, 'params': params}, tbl: tbl, rowId: rowId, label: label);
}

sealed class ExecResult {
  const ExecResult();
}

class ExecOk extends ExecResult {
  final Object? response;
  const ExecOk([this.response]);
}

/// The server said no; retrying will not help. The local change is rolled back.
class ExecRejected extends ExecResult {
  final String reason;
  const ExecRejected(this.reason);
}

/// Could not reach the server (or a transient server error). Stop and retry later.
class ExecRetryLater extends ExecResult {
  final String error;
  const ExecRetryLater(this.error);
}

abstract class OutboxExecutor {
  Future<ExecResult> execute(String kind, Map<String, dynamic> payload);
}

class SupabaseOutboxExecutor implements OutboxExecutor {
  final SupabaseClient _client;
  SupabaseOutboxExecutor(this._client);

  @override
  Future<ExecResult> execute(String kind, Map<String, dynamic> p) async {
    try {
      switch (kind) {
        case 'upsert':
          final onConflict = p['onConflict'] as String?;
          await _client.from(p['table'] as String).upsert(p['row'] as Map<String, dynamic>, onConflict: onConflict);
          return const ExecOk();
        case 'update':
          var q = _client.from(p['table'] as String).update(p['values'] as Map<String, dynamic>);
          for (final e in (p['match'] as Map<String, dynamic>).entries) {
            q = q.eq(e.key, e.value as Object);
          }
          await q;
          return const ExecOk();
        case 'delete':
          var q = _client.from(p['table'] as String).delete();
          for (final e in (p['match'] as Map<String, dynamic>).entries) {
            q = q.eq(e.key, e.value as Object);
          }
          await q;
          return const ExecOk();
        case 'rpc':
          final res = await _client.rpc(p['fn'] as String, params: p['params'] as Map<String, dynamic>?);
          if (res is Map && res['status'] == 'rejected') {
            return ExecRejected('${res['reason'] ?? 'rejected'}');
          }
          return ExecOk(res);
      }
      return ExecRejected('unknown op kind $kind');
    } catch (e) {
      if (isTransientNetworkError(e) || isTransientServerError(e)) return ExecRetryLater('$e');
      if (e is PostgrestException) return ExecRejected('${e.code ?? ''} ${e.message}'.trim());
      return ExecRetryLater('$e');
    }
  }
}

class FlushResult {
  final int sent;
  final int rejected;
  final bool stoppedEarly;
  const FlushResult(this.sent, this.rejected, this.stoppedEarly);
}

class Outbox {
  final AppDatabase db;
  static const _uuid = Uuid();

  /// After this many transient failures an op is treated as rejected, so one bad
  /// op can never block the queue forever.
  static const maxAttempts = 12;

  Outbox(this.db);

  /// Apply a local write and queue its server op atomically.
  ///
  /// [snapshots] are the local rows the write is about to change (read them
  /// before writing); [localWrite] performs the change on [db].
  Future<void> write({
    required OutboxOp op,
    required List<RowSnapshot> snapshots,
    required Future<void> Function() localWrite,
  }) {
    return db.transaction(() async {
      await localWrite();
      await db.into(db.outboxEntries).insert(OutboxEntriesCompanion.insert(
            opId: _uuid.v4(),
            kind: op.kind,
            payload: jsonEncode(op.payload),
            tbl: Value(op.tbl),
            rowId: Value(op.rowId),
            undo: Value(jsonEncode([for (final s in snapshots) s.toJson()])),
            label: Value(op.label),
            createdAt: DateTime.now(),
          ));
    });
  }

  /// (tbl, rowId) of rows with a pending op: pulls must not overwrite them.
  Future<Set<String>> protectedKeys() async {
    final rows = await (db.select(db.outboxEntries)..where((t) => t.status.equals('pending'))).get();
    final keys = <String>{};
    for (final r in rows) {
      if (r.tbl != null && r.rowId != null) keys.add('${r.tbl}\u0000${r.rowId}');
      for (final s in _snapshots(r)) {
        keys.add('${s.tbl}\u0000${s.rowId}');
      }
    }
    return keys;
  }

  static String key(String tbl, String rowId) => '$tbl\u0000$rowId';

  Stream<int> watchPendingCount() {
    final c = db.outboxEntries.id.count();
    final q = db.selectOnly(db.outboxEntries)
      ..addColumns([c])
      ..where(db.outboxEntries.status.equals('pending'));
    return q.watchSingle().map((r) => r.read(c) ?? 0);
  }

  Stream<List<OutboxEntry>> watchFailed() =>
      (db.select(db.outboxEntries)..where((t) => t.status.equals('failed'))).watch();

  Future<int> pendingCount() async =>
      (await (db.select(db.outboxEntries)..where((t) => t.status.equals('pending'))).get()).length;

  Future<void> dismissFailed(int id) => (db.delete(db.outboxEntries)..where((t) => t.id.equals(id))).go();

  /// Send pending ops oldest-first. Stops at the first transient failure so order is kept.
  Future<FlushResult> flush(OutboxExecutor exec) async {
    var sent = 0;
    var rejected = 0;
    while (true) {
      final next = await (db.select(db.outboxEntries)
            ..where((t) => t.status.equals('pending'))
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(1))
          .getSingleOrNull();
      if (next == null) return FlushResult(sent, rejected, false);

      final payload = jsonDecode(next.payload) as Map<String, dynamic>;
      final result = await exec.execute(next.kind, payload);

      switch (result) {
        case ExecOk():
          await (db.delete(db.outboxEntries)..where((t) => t.id.equals(next.id))).go();
          sent++;
        case ExecRejected(:final reason):
          await _reject(next, reason);
          rejected++;
        case ExecRetryLater(:final error):
          final attempts = next.attempts + 1;
          if (attempts >= maxAttempts) {
            await _reject(next, 'gave up after $attempts attempts: $error');
            rejected++;
            continue;
          }
          await (db.update(db.outboxEntries)..where((t) => t.id.equals(next.id)))
              .write(OutboxEntriesCompanion(attempts: Value(attempts), lastError: Value(error)));
          return FlushResult(sent, rejected, true);
      }
    }
  }

  Future<void> _reject(OutboxEntry e, String reason) => db.transaction(() async {
        for (final s in _snapshots(e)) {
          if (s.data == null) {
            await db.deleteRow(s.tbl, s.rowId);
          } else {
            await db.putRow(tbl: s.tbl, rowId: s.rowId, scope: s.scope, semester: s.semester, data: s.data!);
          }
        }
        await (db.update(db.outboxEntries)..where((t) => t.id.equals(e.id))).write(OutboxEntriesCompanion(
              status: const Value('failed'),
              lastError: Value(reason),
              attempts: Value(e.attempts + 1),
            ));
      });

  static List<RowSnapshot> _snapshots(OutboxEntry e) {
    if (e.undo == null) return const [];
    return [for (final j in jsonDecode(e.undo!) as List) RowSnapshot.fromJson(Map<String, dynamic>.from(j as Map))];
  }
}
