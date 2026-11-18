import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_providers.dart';
import '../db/app_database.dart';
import '../sync/outbox.dart';
import '../sync/scope_catalog.dart';
import '../sync/sync_signals.dart';

/// Writes to the user's own data: change the local row immediately (the UI
/// updates through its watch query) and queue the server write in the same
/// transaction. Works the same online and offline.
class LocalWriter {
  final AppDatabase db;
  final Outbox outbox;
  final String userId;

  LocalWriter(this.db, this.outbox, this.userId);

  String get userScope => ScopeCatalog.userScope(userId);

  String _scopeFor(String table) => table == 'notifications' ? ScopeCatalog.notifsScope(userId) : userScope;

  /// Insert or replace a row (must contain its primary key; client-generated UUIDs for new rows).
  Future<void> upsert(
    String table,
    Map<String, dynamic> row, {
    String? onConflict,
    List<String> pk = const ['id'],
    String? label,
  }) async {
    final rowId = ScopeTable(table, pk: pk).rowIdOf(row);
    final before = await db.getRow(table, rowId);
    final merged = {...?before, ...row};
    final scope = _scopeFor(table);
    await outbox.write(
      op: OutboxOp.upsert(table, row, onConflict: onConflict, rowId: rowId, label: label),
      snapshots: [_snap(table, rowId, scope, before)],
      localWrite: () => db.putRow(
        tbl: table,
        rowId: rowId,
        scope: scope,
        semester: ScopeCatalog.semesterOf(table, merged),
        data: merged,
      ),
    );
    SyncSignals.instance.request(reason: 'write $table');
  }

  /// Patch some columns of an existing row (matched by its primary key `id`).
  Future<void> update(String table, String id, Map<String, dynamic> values, {String? label}) async {
    final before = await db.getRow(table, id);
    final scope = _scopeFor(table);
    await outbox.write(
      op: OutboxOp.update(table, {'id': id}, values, rowId: id, label: label),
      snapshots: [_snap(table, id, scope, before)],
      localWrite: () async {
        if (before == null) return; // not known locally: server-side update only
        final merged = {...before, ...values};
        await db.putRow(
            tbl: table, rowId: id, scope: scope, semester: ScopeCatalog.semesterOf(table, merged), data: merged);
      },
    );
    SyncSignals.instance.request(reason: 'update $table');
  }

  Future<void> delete(String table, String id, {String? label}) async {
    final before = await db.getRow(table, id);
    await outbox.write(
      op: OutboxOp.delete(table, {'id': id}, rowId: id, label: label),
      snapshots: [_snap(table, id, _scopeFor(table), before)],
      localWrite: () => db.deleteRow(table, id),
    );
    SyncSignals.instance.request(reason: 'delete $table');
  }

  /// Queue an RPC with optimistic local changes (possibly in several tables).
  /// All of them are rolled back together if the server rejects the call, and
  /// all are protected from being overwritten by pulls while it is pending.
  Future<void> rpc(
    String fn,
    Map<String, dynamic> params, {
    required List<LocalChange> changes,
    String? label,
  }) async {
    final snaps = <RowSnapshot>[];
    for (final c in changes) {
      snaps.add(_snap(c.table, c.rowId, _scopeFor(c.table), await db.getRow(c.table, c.rowId)));
    }
    await outbox.write(
      op: OutboxOp.rpc(fn, params,
          tbl: changes.isEmpty ? null : changes.first.table,
          rowId: changes.isEmpty ? null : changes.first.rowId,
          label: label),
      snapshots: snaps,
      localWrite: () async {
        for (final c in changes) {
          final data = c.data;
          if (data == null) {
            await db.deleteRow(c.table, c.rowId);
          } else {
            await db.putRow(
              tbl: c.table,
              rowId: c.rowId,
              scope: _scopeFor(c.table),
              semester: ScopeCatalog.semesterOf(c.table, data),
              data: data,
            );
          }
        }
      },
    );
    SyncSignals.instance.request(reason: 'rpc $fn');
  }

  RowSnapshot _snap(String table, String rowId, String scope, Map<String, dynamic>? before) => RowSnapshot(
        tbl: table,
        rowId: rowId,
        scope: scope,
        semester: before == null ? null : ScopeCatalog.semesterOf(table, before),
        data: before,
      );
}

/// One optimistic row change of an RPC: new [data], or null to delete the row.
class LocalChange {
  final String table;
  final String rowId;
  final Map<String, dynamic>? data;
  const LocalChange(this.table, this.rowId, this.data);
}

/// Null while signed out.
final localWriterProvider = Provider<LocalWriter?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  return LocalWriter(ref.watch(appDatabaseProvider), ref.watch(outboxProvider), uid);
});

/// Reactive rows of one local table (optionally one semester).
final localRowsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, (String, String?)>((ref, key) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchRows(key.$1, semester: key.$2);
});
