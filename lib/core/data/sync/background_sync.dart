import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../db/app_database.dart';
import 'outbox.dart';
import 'sync_api.dart';
import 'sync_engine.dart';

/// Runs one sync from the FCM background isolate when a silent "scopes changed"
/// message arrives while the app is closed.
///
/// Safety: it never refreshes the auth session (refresh tokens rotate; a second
/// isolate refreshing could sign the user out). It uses the access token the app
/// saved last and skips the run when that token is expired — the app then syncs on open.
Future<void> runBackgroundSync({Duration budget = const Duration(seconds: 25)}) async {
  final db = AppDatabase();
  SupabaseClient? client;
  SyncEngine? engine;
  try {
    final raw = await db.getValue('bg_session');
    if (raw == null) return;
    final s = jsonDecode(raw) as Map<String, dynamic>;
    final expiresAt = (s['expires_at'] as num?)?.toInt();
    final token = s['access_token'] as String?;
    final uid = s['user_id'] as String?;
    if (token == null || uid == null || expiresAt == null) return;
    if (DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000).isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      await db.setValue('sync_requested_while_closed', DateTime.now().toIso8601String());
      return;
    }

    client = SupabaseClient(AppConfig.getSupabaseUrl, AppConfig.getSupabaseAnonKey, accessToken: () async => token);
    engine = SyncEngine(
      db: db,
      api: SupabaseSyncApi(client),
      outbox: Outbox(db),
      executor: SupabaseOutboxExecutor(client),
      userId: uid,
    );
    final report = await engine.sync().timeout(budget);
    if (report.ok) await db.setValue('last_sync_ok', report.finishedAt.toIso8601String());
  } catch (e) {
    if (kDebugMode) debugPrint('[BackgroundSync] $e');
  } finally {
    await engine?.dispose();
    await client?.dispose();
    await db.close();
  }
}
