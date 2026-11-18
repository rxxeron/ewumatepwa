import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Every row the app has from the server, stored once, keyed by (server table, row id).
///
/// One generic table instead of one Drift table per server table: the sync engine
/// stays table-agnostic, and a new server column never needs a local migration.
/// Typed models parse [data] on read.
@DataClassName('SyncedRow')
@TableIndex(name: 'synced_rows_tbl_semester', columns: {#tbl, #semester})
@TableIndex(name: 'synced_rows_scope', columns: {#scope})
class SyncedRows extends Table {
  /// Local table name (usually the server table name; see ScopeCatalog).
  TextColumn get tbl => text()();
  TextColumn get rowId => text()();
  TextColumn get scope => text()();

  /// Canonical semester key (e.g. `fall2026`) when the row belongs to one.
  TextColumn get semester => text().nullable()();

  /// The server row as JSON.
  TextColumn get data => text()();

  @override
  Set<Column> get primaryKey => {tbl, rowId};
}

/// Sync state per scope (`user:<uid>`, `meta`, `courses:fall2026`, ...).
@DataClassName('SyncScopeState')
class SyncScopes extends Table {
  TextColumn get scope => text()();
  IntColumn get version => integer().nullable()();

  /// Server cursor (transaction-id snapshot) the scope is complete up to.
  TextColumn get cursor => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {scope};
}

/// Writes made locally that still have to reach the server (FIFO).
@DataClassName('OutboxEntry')
class OutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get opId => text().unique()();

  /// upsert | update | delete | rpc
  TextColumn get kind => text()();
  TextColumn get payload => text()();

  /// Local row this op protects from being overwritten by a pull while pending.
  TextColumn get tbl => text().nullable()();
  TextColumn get rowId => text().nullable()();

  /// JSON list of {tbl, rowId, scope, semester, data|null}: local rows to restore if the server rejects the op.
  TextColumn get undo => text().nullable()();

  /// Human label for the "Sync issues" list, e.g. "Enroll in CSE101 section 3".
  TextColumn get label => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  /// pending | failed
  TextColumn get status => text().withDefault(const Constant('pending'))();
}

/// Small local settings (last FCM token saved, Hive import done, ...).
@DataClassName('KeyValue')
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [SyncedRows, SyncScopes, OutboxEntries, KeyValues])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  /// The app's database (set in main), for the few legacy classes built without Riverpod.
  static AppDatabase? _main;
  static AppDatabase get main => _main ?? (throw StateError('AppDatabase.main not set (main() not run?)'));
  static set main(AppDatabase db) => _main = db;

  static QueryExecutor _openDefault() => driftDatabase(
        name: 'ewumate_local',
        // The FCM background handler runs in another isolate and opens the same file.
        native: const DriftNativeOptions(shareAcrossIsolates: true),
        // PWA: SQLite compiled to WebAssembly, stored in the browser (OPFS / IndexedDB).
        // Files served from web/: sqlite3.wasm (sqlite3 3.9.1), drift_worker.js (drift 2.35.4).
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ---------------------------------------------------------------------------
  // Rows
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> decode(SyncedRow r) => jsonDecode(r.data) as Map<String, dynamic>;

  Future<Map<String, dynamic>?> getRow(String tbl, String rowId) async {
    final r = await (select(syncedRows)..where((t) => t.tbl.equals(tbl) & t.rowId.equals(rowId))).getSingleOrNull();
    return r == null ? null : decode(r);
  }

  Future<List<Map<String, dynamic>>> getRows(String tbl, {String? semester}) async {
    final q = select(syncedRows)..where((t) => t.tbl.equals(tbl));
    if (semester != null) q.where((t) => t.semester.equals(semester));
    return (await q.get()).map(decode).toList();
  }

  Stream<List<Map<String, dynamic>>> watchRows(String tbl, {String? semester}) {
    final q = select(syncedRows)..where((t) => t.tbl.equals(tbl));
    if (semester != null) q.where((t) => t.semester.equals(semester));
    return q.watch().map((rows) => rows.map(decode).toList());
  }

  Stream<Map<String, dynamic>?> watchRow(String tbl, String rowId) {
    final q = select(syncedRows)..where((t) => t.tbl.equals(tbl) & t.rowId.equals(rowId));
    return q.watchSingleOrNull().map((r) => r == null ? null : decode(r));
  }

  Future<void> putRow({
    required String tbl,
    required String rowId,
    required String scope,
    String? semester,
    required Map<String, dynamic> data,
  }) {
    return into(syncedRows).insertOnConflictUpdate(SyncedRowsCompanion.insert(
      tbl: tbl,
      rowId: rowId,
      scope: scope,
      semester: Value(semester),
      data: jsonEncode(data),
    ));
  }

  Future<int> deleteRow(String tbl, String rowId) =>
      (delete(syncedRows)..where((t) => t.tbl.equals(tbl) & t.rowId.equals(rowId))).go();

  // ---------------------------------------------------------------------------
  // Key/value
  // ---------------------------------------------------------------------------

  Future<String?> getValue(String key) async =>
      (await (select(keyValues)..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setValue(String key, String? value) =>
      into(keyValues).insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: Value(value)));

  // ---------------------------------------------------------------------------
  // Sign-out: drop everything that belongs to the user (shared data is kept).
  // ---------------------------------------------------------------------------
  Future<void> clearUserData() => transaction(() async {
        await (delete(syncedRows)..where((t) => t.scope.like('user:%') | t.scope.like('notifs:%'))).go();
        await (delete(syncScopes)..where((t) => t.scope.like('user:%') | t.scope.like('notifs:%'))).go();
        await delete(outboxEntries).go();
      });
}
