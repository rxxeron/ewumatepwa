import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ewumate/core/data/db/app_database.dart';
import 'package:ewumate/core/data/sync/outbox.dart';
import 'package:ewumate/core/data/sync/scope_catalog.dart';
import 'package:ewumate/core/data/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_sync_server.dart';

const uid = 'u1';
const userScope = 'user:u1';

void main() {
  late AppDatabase db;
  late FakeSyncServer server;
  late FakeExecutor exec;
  late Outbox outbox;
  late SyncEngine engine;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    server = FakeSyncServer();
    exec = FakeExecutor(server, userScope);
    outbox = Outbox(db);
    engine = SyncEngine(
      db: db,
      api: server,
      outbox: outbox,
      executor: exec,
      userId: uid,
      pickSemesters: (_, __) async => {'fall2026'},
      pageSize: 2,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<List<Map<String, dynamic>>> tasks() => db.getRows('tasks');

  test('first sync pulls everything (paged) and records the cursor', () async {
    for (var i = 0; i < 5; i++) {
      server.write(userScope, 'tasks', 't$i', {'id': 't$i', 'user_id': uid, 'title': 'T$i'});
    }
    server.write('meta', 'active_semester', 'tri_semester',
        {'track': 'tri_semester', 'current_semester_code': 'Fall 2026', 'next_semester_code': 'Spring2027'});

    final r = await engine.sync();

    expect(r.ok, isTrue);
    expect((await tasks()).length, 5);
    final scope = await (db.select(db.syncScopes)..where((t) => t.scope.equals(userScope))).getSingle();
    expect(scope.cursor, isNotNull);
    expect(scope.version, server.versions[userScope]);
  });

  test('nothing changed -> no pulls', () async {
    server.write(userScope, 'tasks', 't1', {'id': 't1', 'title': 'a'});
    await engine.sync();
    final pullsBefore = server.pulls;

    await engine.sync();

    expect(server.pulls, pullsBefore);
  });

  test('delta: only changed rows are fetched; tombstones delete', () async {
    server.write(userScope, 'tasks', 't1', {'id': 't1', 'title': 'a'});
    server.write(userScope, 'tasks', 't2', {'id': 't2', 'title': 'b'});
    await engine.sync();

    server.write(userScope, 'tasks', 't1', {'id': 't1', 'title': 'a2'});
    server.remove(userScope, 'tasks', 't2');
    await engine.sync();

    final rows = await tasks();
    expect(rows.map((r) => r['id']), ['t1']);
    expect(rows.single['title'], 'a2');
  });

  test('a write committed after the check is not lost (picked up next time)', () async {
    server.write(userScope, 'tasks', 't1', {'id': 't1', 'title': 'a'});
    await engine.sync();
    // Simulates a long transaction: row stamped with an xid below the saved cursor would be
    // a bug; the fake stamps with a fresh xid >= cursor, mirroring pg_snapshot_xmin semantics.
    server.write(userScope, 'tasks', 't3', {'id': 't3', 'title': 'late'});
    await engine.sync();
    expect((await tasks()).map((r) => r['id']).toSet(), {'t1', 't3'});
  });

  test('cursor older than the tombstone horizon -> full resync drops vanished rows', () async {
    server.write(userScope, 'tasks', 't1', {'id': 't1'});
    server.write(userScope, 'tasks', 't2', {'id': 't2'});
    await engine.sync();

    server.remove(userScope, 'tasks', 't2');
    server.purgeTombstonesUpTo(server.currentXid + 1);
    server.write(userScope, 'tasks', 't1', {'id': 't1', 'title': 'x'});
    await engine.sync();

    expect((await tasks()).map((r) => r['id']), ['t1']);
  });

  test('full-style tables are replaced', () async {
    server.write('reference', 'grade_scale', 'A|modern', {'grade': 'A', 'policy': 'modern', 'point': 4});
    server.write('reference', 'grade_scale', 'B|modern', {'grade': 'B', 'policy': 'modern', 'point': 3});
    await engine.sync();
    expect((await db.getRows('grade_scale')).length, 2);

    server.remove('reference', 'grade_scale', 'B|modern');
    await engine.sync();
    expect((await db.getRows('grade_scale')).map((r) => r['grade']), ['A']);
  });

  test('semester scopes: courses stored with canonical semester key', () async {
    server.write('courses:fall2026', 'courses_fall2026', 's1', {'id': 's1', 'course_code': 'CSE101'});
    await engine.sync();
    final rows = await db.getRows('courses_fall2026', semester: 'fall2026');
    expect(rows.single['course_code'], 'CSE101');
  });

  test('pending outbox rows are not overwritten by a pull', () async {
    server.write(userScope, 'tasks', 't1', {'id': 't1', 'title': 'server'});
    await engine.sync();

    server.offline = true;
    await outbox.write(
      op: OutboxOp.upsert('tasks', {'id': 't1', 'title': 'local edit'}),
      snapshots: [RowSnapshot(tbl: 'tasks', rowId: 't1', scope: userScope, data: {'id': 't1', 'title': 'server'})],
      localWrite: () => db.putRow(tbl: 'tasks', rowId: 't1', scope: userScope, data: {'id': 't1', 'title': 'local edit'}),
    );
    final offlineRun = await engine.sync();
    expect(offlineRun.offline, isTrue);
    expect((await db.getRow('tasks', 't1'))!['title'], 'local edit');

    // Someone else changes the row on the server meanwhile; our edit is still queued.
    server.offline = false;
    server.write(userScope, 'tasks', 't1', {'id': 't1', 'title': 'server 2'});
    // Flush happens first in the run, then the pull brings back the server's final state (ours, last writer).
    await engine.sync();
    expect((await db.getRow('tasks', 't1'))!['title'], 'local edit');
    expect(await outbox.pendingCount(), 0);
  });

  test('outbox is FIFO and survives offline; flushes when back online', () async {
    server.offline = true;
    for (final id in ['a', 'b', 'c']) {
      await outbox.write(
        op: OutboxOp.upsert('tasks', {'id': id, 'title': id}),
        snapshots: [RowSnapshot(tbl: 'tasks', rowId: id, scope: userScope)],
        localWrite: () => db.putRow(tbl: 'tasks', rowId: id, scope: userScope, data: {'id': id, 'title': id}),
      );
    }
    await engine.sync();
    expect(await outbox.pendingCount(), 3);

    server.offline = false;
    await engine.sync();
    expect(await outbox.pendingCount(), 0);
    expect(exec.executed.map((e) => (e.$2['row'] as Map)['id']), ['a', 'b', 'c']);
    expect((await tasks()).length, 3);
  });

  test('rejected op rolls the local change back and is listed as failed', () async {
    server.write(userScope, 'enrollments', 'e1', {'id': 'e1', 'section_id': 'old'});
    await engine.sync();
    exec.rejectRpc['v2_switch_section'] = 'section_changed';

    await outbox.write(
      op: OutboxOp.rpc('v2_switch_section', {'p_new_section_id': 'new'}, tbl: 'enrollments', rowId: 'e1', label: 'Switch'),
      snapshots: [RowSnapshot(tbl: 'enrollments', rowId: 'e1', scope: userScope, data: {'id': 'e1', 'section_id': 'old'})],
      localWrite: () => db.putRow(
          tbl: 'enrollments', rowId: 'e1', scope: userScope, data: {'id': 'e1', 'section_id': 'new', '_pending': true}),
    );
    final r = await engine.sync();

    expect(r.outboxRejected, 1);
    expect((await db.getRow('enrollments', 'e1'))!['section_id'], 'old');
    final failed = await outbox.watchFailed().first;
    expect(failed.single.lastError, 'section_changed');
    expect(failed.single.label, 'Switch');
  });

  test('concurrent sync calls share one run and schedule exactly one more', () async {
    server.write(userScope, 'tasks', 't1', {'id': 't1'});
    final a = engine.sync();
    final b = engine.sync();
    final c = engine.sync();
    await Future.wait([a, b, c]);
    expect(server.checks, 2);
  });

  test('semester key normalisation', () {
    expect(normSemester('Fall 2026'), 'fall2026');
    expect(normSemester('SPRING_2027'), 'spring2027');
    expect(normSemester('summer-2026'), 'summer2026');
    expect(ScopeCatalog.coursesScope('Fall 2026'), 'courses:fall2026');
  });

  test('own reviews and public reviews are stored apart', () async {
    server.write(userScope, 'faculty_reviews', 'r1', {'id': 'r1', 'status': 'pending'});
    server.write('reviews', 'faculty_reviews', 'r2', {'id': 'r2', 'status': 'approved'});
    await engine.sync();
    expect((await db.getRows('my_faculty_reviews')).single['id'], 'r1');
    expect((await db.getRows('faculty_reviews')).single['id'], 'r2');
  });
}
