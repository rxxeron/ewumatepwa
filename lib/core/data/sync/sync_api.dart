import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of `sync_check()`.
class SyncCheck {
  final String cursor;
  final DateTime serverTime;
  final Map<String, int> versions;
  final Set<String> semesterTables;

  const SyncCheck({
    required this.cursor,
    required this.serverTime,
    required this.versions,
    required this.semesterTables,
  });

  factory SyncCheck.fromJson(Map<String, dynamic> j) => SyncCheck(
        cursor: j['cursor'].toString(),
        serverTime: DateTime.tryParse('${j['server_time']}') ?? DateTime.now(),
        versions: {
          for (final e in ((j['versions'] as Map?) ?? const {}).entries) e.key.toString(): (e.value as num).toInt(),
        },
        semesterTables: {for (final t in (j['semester_tables'] as List? ?? const [])) t.toString()},
      );
}

class PullPage {
  final List<Map<String, dynamic>> rows;
  final String? next;
  const PullPage(this.rows, this.next);
}

class Tombstones {
  final bool resync;

  /// (server table, row id)
  final List<(String, String)> items;
  const Tombstones(this.resync, this.items);
}

/// Server API the sync engine talks to. Abstract so tests can use a fake.
abstract class SyncApi {
  Future<SyncCheck> check();
  Future<PullPage> pull(String scope, String table, {String? since, String? after, int limit = 1000});
  Future<Tombstones> tombstones(String scope, String since);
}

class SupabaseSyncApi implements SyncApi {
  final SupabaseClient _client;
  SupabaseSyncApi(this._client);

  static const _timeout = Duration(seconds: 30);

  @override
  Future<SyncCheck> check() async {
    final res = await _client.rpc('sync_check').timeout(_timeout);
    return SyncCheck.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<PullPage> pull(String scope, String table, {String? since, String? after, int limit = 1000}) async {
    final res = await _client.rpc('sync_pull', params: {
      'p_scope': scope,
      'p_table': table,
      'p_since': since,
      'p_after': after,
      'p_limit': limit,
    }).timeout(_timeout);
    final m = Map<String, dynamic>.from(res as Map);
    return PullPage(
      [for (final r in (m['rows'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)],
      m['next'] as String?,
    );
  }

  @override
  Future<Tombstones> tombstones(String scope, String since) async {
    final res = await _client.rpc('sync_tombstones', params: {'p_scope': scope, 'p_since': since}).timeout(_timeout);
    final m = Map<String, dynamic>.from(res as Map);
    return Tombstones(
      m['resync'] == true,
      [for (final t in (m['tombstones'] as List? ?? const [])) ('${(t as Map)['t']}', '${t['id']}')],
    );
  }
}

/// True for failures that mean "no usable network right now" (retry later),
/// as opposed to the server rejecting the request.
bool isTransientNetworkError(Object e) {
  if (e is SocketException || e is TimeoutException || e is HttpException) return true;
  if (e is AuthRetryableFetchException) return true;
  final s = e.toString();
  return s.contains('ClientException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection closed') ||
      s.contains('Connection reset') ||
      s.contains('Network is unreachable') ||
      s.contains('SocketException');
}

/// Postgres / PostgREST errors worth retrying (serialization, deadlock, timeout, expired JWT, overload).
bool isTransientServerError(Object e) {
  if (e is PostgrestException) {
    const retry = {'40001', '40P01', '57014', '53300', '55P03', 'PGRST301', '503', '504', '502'};
    return retry.contains(e.code);
  }
  return false;
}
