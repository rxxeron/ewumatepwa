import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/connectivity_provider.dart';
import 'db/app_database.dart';
import 'sync/outbox.dart';
import 'sync/sync_api.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_signals.dart';
import 'sync/sync_status.dart';

/// The local database. Opened in main() and injected with an override so the
/// first frame can already read from it.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Signed-in user id (null when signed out). Changes only on sign-in/out.
class CurrentUserId extends Notifier<String?> {
  @override
  String? build() {
    try {
      final auth = Supabase.instance.client.auth;
      final sub = auth.onAuthStateChange.listen((s) {
        final id = s.session?.user.id;
        if (id != state) state = id;
      });
      ref.onDispose(sub.cancel);
      return auth.currentUser?.id;
    } catch (_) {
      return null; // Supabase failed to initialise; app runs from local data only
    }
  }
}

final currentUserIdProvider = NotifierProvider<CurrentUserId, String?>(CurrentUserId.new);

final outboxProvider = Provider<Outbox>((ref) => Outbox(ref.watch(appDatabaseProvider)));

final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  final client = Supabase.instance.client;
  final engine = SyncEngine(
    db: ref.watch(appDatabaseProvider),
    api: SupabaseSyncApi(client),
    outbox: ref.watch(outboxProvider),
    executor: SupabaseOutboxExecutor(client),
    userId: uid,
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// Reads the server kill switch `app_config['sync_v2']` from local data.
Future<Map<String, dynamic>> readSyncFlags(AppDatabase db) async {
  final row = await db.getRow('app_config', 'sync_v2');
  final v = row?['value'];
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String) {
    try {
      return Map<String, dynamic>.from(jsonDecode(v) as Map);
    } catch (_) {}
  }
  return const {'enabled': true, 'realtime': true, 'push': true};
}

/// Wires every "something may have changed" trigger to one debounced sync:
/// first frame, app resume, network back, Realtime on sync.versions, FCM data
/// message, pull-to-refresh / local writes (via [SyncSignals]).
class SyncCoordinator {
  final Ref _ref;
  final SyncEngine _engine;
  final AppDatabase _db;
  final SupabaseClient _client;

  final _subs = <StreamSubscription<dynamic>>[];
  AppLifecycleListener? _lifecycle;
  RealtimeChannel? _channel;
  Timer? _debounce;
  bool _pendingForce = false;
  bool _disposed = false;

  SyncCoordinator(this._ref, this._engine, this._db, this._client);

  void start() {
    _subs.add(SyncSignals.instance.stream.listen((r) => schedule(force: r.force)));
    _lifecycle = AppLifecycleListener(onResume: schedule);
    _ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
      if (prev?.value == false && next.value == true) schedule();
    });
    _subs.add(_client.auth.onAuthStateChange.listen((s) => _saveSessionForBackground(s.session)));
    _saveSessionForBackground(_client.auth.currentSession);

    // After the first frame: the UI is already showing local data by then.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_disposed) return;
      schedule(delay: Duration.zero);
      final flags = await readSyncFlags(_db);
      if (_disposed || flags['enabled'] == false) return;
      if (flags['realtime'] != false) _subscribeRealtime();
      if (flags['push'] != false) unawaited(_registerPush());
    });
  }

  /// Debounced: bursts of triggers (Realtime fan-out, typing) become one sync.
  void schedule({bool force = false, Duration delay = const Duration(milliseconds: 600)}) {
    if (_disposed) return;
    _pendingForce |= force;
    _debounce?.cancel();
    _debounce = Timer(delay, () {
      final f = _pendingForce;
      _pendingForce = false;
      unawaited(_engine.sync(force: f));
    });
  }

  Future<SyncReport> syncNow({bool force = false}) => _engine.sync(force: force);

  void _subscribeRealtime() {
    _channel = _client
        .channel('sync-versions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'sync',
          table: 'versions',
          callback: (_) => schedule(delay: const Duration(seconds: 2)),
        )
        .subscribe();
  }

  /// Silent data pushes go to devices registered here (sync.device_tokens) and
  /// the `sync_v2` topic — never to old app installs.
  Future<void> _registerPush() async {
    if (kIsWeb || Firebase.apps.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token == null) return;
      final uid = _engine.userId;
      final saved = await _db.getValue('sync_push_registration');
      if (saved != '$uid|$token') {
        final info = await PackageInfo.fromPlatform();
        await _client.rpc('sync_register_device', params: {
          'p_token': token,
          'p_platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
          'p_app_build': info.buildNumber,
        });
        await _db.setValue('sync_push_registration', '$uid|$token');
      }
      if (await _db.getValue('sync_topic_subscribed') != '1') {
        await messaging.subscribeToTopic('sync_v2');
        await _db.setValue('sync_topic_subscribed', '1');
      }
      // ignore: deprecated_member_use
      _subs.add(messaging.onTokenRefresh.listen((_) async {
        await _db.setValue('sync_push_registration', null);
        await _registerPush();
      }));
    } catch (e) {
      if (kDebugMode) debugPrint('[SyncCoordinator] push registration failed: $e');
    }
  }

  /// The FCM background isolate must never refresh the session itself (refresh
  /// tokens rotate; two isolates refreshing can sign the user out). It only uses
  /// the access token saved here, and only while it is still valid.
  Future<void> _saveSessionForBackground(Session? s) async {
    if (s == null) return;
    await _db.setValue('bg_session', jsonEncode({
      'user_id': s.user.id,
      'access_token': s.accessToken,
      'expires_at': s.expiresAt,
    }));
  }

  /// Called before sign-out: drop this device from silent pushes.
  Future<void> unregisterPush() async {
    if (kIsWeb || Firebase.apps.isEmpty) return;
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _client.rpc('sync_unregister_device', params: {'p_token': token});
      await FirebaseMessaging.instance.unsubscribeFromTopic('sync_v2');
    } catch (_) {}
    await _db.setValue('sync_push_registration', null);
    await _db.setValue('sync_topic_subscribed', null);
    await _db.setValue('bg_session', null);
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _lifecycle?.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    final ch = _channel;
    if (ch != null) unawaited(_client.removeChannel(ch));
  }
}

final syncCoordinatorProvider = Provider<SyncCoordinator?>((ref) {
  final engine = ref.watch(syncEngineProvider);
  if (engine == null) return null;
  final c = SyncCoordinator(ref, engine, ref.watch(appDatabaseProvider), Supabase.instance.client)..start();
  ref.onDispose(c.dispose);
  return c;
});

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final db = ref.watch(appDatabaseProvider);
    final outbox = ref.watch(outboxProvider);
    final engine = ref.watch(syncEngineProvider);
    final online = ref.watch(connectivityProvider).value ?? true;

    final subs = <StreamSubscription<dynamic>>[
      outbox.watchPendingCount().listen((n) => state = state.copyWith(pending: n)),
      outbox.watchFailed().listen((f) => state = state.copyWith(failed: f.length)),
      if (engine != null) engine.busy.listen((b) => state = state.copyWith(syncing: b)),
      if (engine != null)
        engine.reports.listen((r) async {
          if (r.offline) {
            state = state.copyWith(online: false);
            return;
          }
          // The run reached the server. One data group failing (logged per scope,
          // retried next sync) must not make the whole app look stale; only a
          // failure of the run itself ('*') is shown to the student.
          final runFailed = r.errors.containsKey('*');
          if (!runFailed) {
            await db.setValue('last_sync_ok', r.finishedAt.toIso8601String());
            state = state.copyWith(online: true, lastSyncedAt: r.finishedAt, clearError: true);
          } else {
            state = state.copyWith(online: true, lastError: r.errors['*']);
          }
          if (kDebugMode && r.errors.isNotEmpty) debugPrint('[Sync] scope errors: ${r.errors}');
        }),
    ];
    ref.onDispose(() {
      for (final s in subs) {
        s.cancel();
      }
    });

    db.getValue('last_sync_ok').then((v) {
      final t = v == null ? null : DateTime.tryParse(v);
      if (t != null) state = state.copyWith(lastSyncedAt: t);
    });

    return SyncStatus(online: online, syncing: engine?.isRunning ?? false);
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);
