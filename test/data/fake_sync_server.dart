import 'package:ewumate/core/data/sync/outbox.dart';
import 'package:ewumate/core/data/sync/sync_api.dart';

/// In-memory model of the server sync layer (sync_v2 SQL): rows carry the
/// "transaction id" that last wrote them, deletes leave tombstones, and every
/// write bumps the scope's version. Writes go through [write]/[remove].
class FakeSyncServer implements SyncApi {
  int _xid = 100;
  int _version = 0;

  /// scope -> table -> rowId -> (xid, row)
  final Map<String, Map<String, Map<String, (int, Map<String, dynamic>)>>> _rows = {};
  final List<(String scope, String table, String rowId, int xid)> _tombstones = [];
  final Map<String, int> versions = {};
  final Set<String> semesterTables = {};
  int horizon = 0;

  int checks = 0;
  int pulls = 0;
  bool offline = false;

  void write(String scope, String table, String rowId, Map<String, dynamic> row) {
    final x = ++_xid;
    _rows.putIfAbsent(scope, () => {}).putIfAbsent(table, () => {})[rowId] = (x, row);
    versions[scope] = ++_version;
    if (table.startsWith('courses_') || table.startsWith('calendar_')) semesterTables.add(table);
  }

  void remove(String scope, String table, String rowId) {
    final x = ++_xid;
    _rows[scope]?[table]?.remove(rowId);
    _tombstones.add((scope, table, rowId, x));
    versions[scope] = ++_version;
  }

  void purgeTombstonesUpTo(int xid) {
    _tombstones.removeWhere((t) => t.$4 <= xid);
    horizon = xid;
  }

  int get currentXid => _xid;

  void _net() {
    if (offline) throw const _Offline();
  }

  @override
  Future<SyncCheck> check() async {
    _net();
    checks++;
    return SyncCheck(
      cursor: '${_xid + 1}',
      serverTime: DateTime.now(),
      versions: Map.of(versions),
      semesterTables: Set.of(semesterTables),
    );
  }

  @override
  Future<PullPage> pull(String scope, String table, {String? since, String? after, int limit = 1000}) async {
    _net();
    pulls++;
    final s = since == null ? null : int.parse(since);
    final entries = (_rows[scope]?[table]?.entries.toList() ?? [])
      ..sort((a, b) => a.key.compareTo(b.key));
    final matching = entries
        .where((e) => s == null || e.value.$1 >= s)
        .where((e) => after == null || e.key.compareTo(after) > 0)
        .toList();
    final page = matching.take(limit).toList();
    return PullPage(
      [for (final e in page) Map<String, dynamic>.from(e.value.$2)],
      page.length >= limit ? page.last.key : null,
    );
  }

  @override
  Future<Tombstones> tombstones(String scope, String since) async {
    _net();
    final s = int.parse(since);
    if (s <= horizon) return const Tombstones(true, []);
    return Tombstones(false, [
      for (final t in _tombstones)
        if (t.$1 == scope && t.$4 >= s) (t.$2, t.$3),
    ]);
  }
}

class _Offline implements Exception {
  const _Offline();
  @override
  String toString() => 'SocketException: Network is unreachable';
}

/// Executes outbox ops against a [FakeSyncServer].
class FakeExecutor implements OutboxExecutor {
  final FakeSyncServer server;
  final String userScope;
  final List<(String, Map<String, dynamic>)> executed = [];

  /// rpc name -> reason: that rpc is rejected.
  final Map<String, String> rejectRpc = {};

  FakeExecutor(this.server, this.userScope);

  @override
  Future<ExecResult> execute(String kind, Map<String, dynamic> payload) async {
    if (server.offline) return const ExecRetryLater('SocketException');
    executed.add((kind, payload));
    switch (kind) {
      case 'upsert':
        final row = Map<String, dynamic>.from(payload['row'] as Map);
        server.write(userScope, payload['table'] as String, '${row['id']}', row);
        return const ExecOk();
      case 'delete':
        final match = payload['match'] as Map;
        server.remove(userScope, payload['table'] as String, '${match['id']}');
        return const ExecOk();
      case 'rpc':
        final reason = rejectRpc[payload['fn']];
        if (reason != null) return ExecRejected(reason);
        return const ExecOk({'status': 'ok'});
    }
    return const ExecOk();
  }
}
