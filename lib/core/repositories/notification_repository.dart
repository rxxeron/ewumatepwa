import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/data_providers.dart';
import '../data/db/app_database.dart';
import '../data/repos/local_writer.dart';
import '../data/sync/outbox.dart';
import '../data/sync/scope_catalog.dart';
import '../data/sync/sync_signals.dart';
import '../models/notification.dart' as model;
import 'auth_repository.dart';

part 'notification_repository.g.dart';

/// In-app notifications from the local database (scope `notifs:<uid>`), kept in
/// step by the sync engine (Realtime on sync.versions while open, pull on resume
/// and when a push arrives). Read/delete work offline and are queued.
class NotificationRepository {
  final AppDatabase _db;
  final Outbox _outbox;

  NotificationRepository(this._db, this._outbox);

  static model.Notification? _parse(Map<String, dynamic> json) {
    final j = Map<String, dynamic>.from(json);
    if (j['payload'] is String) {
      try {
        j['payload'] = jsonDecode(j['payload'] as String);
      } catch (_) {
        j['payload'] = null;
      }
    }
    try {
      return model.Notification.fromJson(j);
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] bad row ${json['id']}: $e');
      return null;
    }
  }

  static List<model.Notification> _visible(List<Map<String, dynamic>> rows, String userId) {
    final list = rows
        .where((r) => r['user_id'] == userId && r['is_dispatched'] == true)
        .map(_parse)
        .whereType<model.Notification>()
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list.take(50).toList();
  }

  Stream<List<model.Notification>> streamNotifications(String userId) =>
      _db.watchRows('notifications').map((rows) => _visible(rows, userId));

  Future<List<model.Notification>> getLocalNotificationsAsync(String userId) async =>
      _visible(await _db.getRows('notifications'), userId);

  /// A push arrived in the foreground: its row is on the server; pull it rather
  /// than storing a copy under the FCM message id (which would duplicate it).
  Future<void> saveLocalNotification(model.Notification notification) async {
    SyncSignals.instance.request(reason: 'notification received');
  }

  Future<void> markAsRead(String notificationId) async {
    final row = await _db.getRow('notifications', notificationId);
    final uid = row?['user_id'] as String?;
    if (uid == null) return;
    await LocalWriter(_db, _outbox, uid).update('notifications', notificationId, {'is_read': true});
  }

  /// One queued server update for all unread notifications.
  Future<void> markAllAsRead(String userId) async {
    final unread = (await _db.getRows('notifications'))
        .where((r) => r['user_id'] == userId && r['is_read'] != true)
        .toList();
    if (unread.isEmpty) return;
    final scope = ScopeCatalog.notifsScope(userId);
    await _outbox.write(
      op: OutboxOp.update('notifications', {'user_id': userId, 'is_read': false}, {'is_read': true},
          rowId: '${unread.first['id']}', label: 'Mark notifications read'),
      snapshots: [
        for (final r in unread) RowSnapshot(tbl: 'notifications', rowId: '${r['id']}', scope: scope, data: r),
      ],
      localWrite: () async {
        for (final r in unread) {
          await _db.putRow(tbl: 'notifications', rowId: '${r['id']}', scope: scope, data: {...r, 'is_read': true});
        }
      },
    );
    SyncSignals.instance.request(reason: 'mark all read');
  }

  Future<void> deleteNotification(String notificationId) async {
    final row = await _db.getRow('notifications', notificationId);
    final uid = row?['user_id'] as String?;
    if (uid == null) return;
    await LocalWriter(_db, _outbox, uid).delete('notifications', notificationId, label: 'Delete notification');
  }
}

@riverpod
NotificationRepository notificationRepository(Ref ref) {
  return NotificationRepository(ref.watch(appDatabaseProvider), ref.watch(outboxProvider));
}

@Riverpod(keepAlive: true)
Stream<List<model.Notification>> userNotifications(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const Stream.empty();
  }
  return ref.watch(notificationRepositoryProvider).streamNotifications(user.id);
}
