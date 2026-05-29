import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../widgets/glass_kit.dart';
import '../repositories/notification_repository.dart';
import '../models/notification.dart' as model;

class PendingNotificationAction {
  final String title;
  final String body;
  final String? url;

  PendingNotificationAction({
    required this.title,
    required this.body,
    this.url,
  });
}

final fcmServiceProvider = Provider<FCMService>((ref) => FCMService(ref));

class FCMService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool isDashboardStable = false;
  PendingNotificationAction? _pendingAction;
  PendingNotificationAction? get pendingAction => _pendingAction;

  void clearPendingAction() {
    _pendingAction = null;
  }

  FCMService(this._ref);

  Future<void> initialize() async {
    print("[FCM] initialize() started...");
    // 0. Register Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle terminated-state notification tap (app was fully closed)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        _handleIncomingAction(
          initialMessage.notification?.title,
          initialMessage.notification?.body,
          initialMessage.data['url'] as String?,
        );
      });
    }

    // 1. Setup Local Notifications for Foreground and Channel Creation
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            final data = jsonDecode(payload);
            _handleIncomingAction(data['title'], data['body'], data['url']);
          } catch (_) {}
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ewumate_high_priority_reminders_v1', 
      'Task Reminders',
      description: 'Notifications for class and task timing',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(channel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register message listeners unconditionally so they are active as soon as permission is granted
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        final routingUrl = message.data['url'] as String?;
        
        // Save locally
        try {
          final userId = _supabase.auth.currentUser?.id;
          if (userId != null) {
            final newNotif = model.Notification(
              id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
              userId: userId,
              title: notification.title ?? 'No Title',
              body: notification.body ?? 'No Message',
              type: message.data['type'] ?? 'system',
              isRead: false,
              createdAt: message.sentTime ?? DateTime.now(),
              payload: message.data.isNotEmpty ? message.data : null,
            );
            _ref.read(notificationRepositoryProvider).saveLocalNotification(newNotif);
          }
        } catch (_) {}

        if (kIsWeb) {
          showNotificationPopup(
            notification.title ?? 'No Title',
            notification.body ?? 'No Message',
            routingUrl,
          );
        } else {
          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher',
                importance: channel.importance,
                priority: Priority.high,
              ),
              iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
            ),
            payload: jsonEncode({'title': notification.title, 'body': notification.body, 'url': routingUrl}),
          );
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Add 800ms delay to let the app resume and route state settle perfectly
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleIncomingAction(
          message.notification?.title, 
          message.notification?.body, 
          message.data['url'] as String?
        );
      });
    });

    // Check permission status silently without prompting on startup (mandatory for iOS Safari)
    NotificationSettings settings = await _messaging.getNotificationSettings();
    print("[FCM] Current AuthorizationStatus on startup: ${settings.authorizationStatus}");

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final vapidKey = kIsWeb ? (dotenv.env['FCM_VAPID_KEY'] ?? 'BO0Po4qenG7jOO_N-TIl1Ers3m46ehFoPthGQJ__Wxz9hjfuNtLNu6lqDsM_Cndjw6AADbo_x-E4K3Nu9mr_dI8') : null;
      print("[FCM] Fetching token silently with VAPID Key: $vapidKey");
      try {
        final token = await _messaging.getToken(vapidKey: vapidKey);
        print("[FCM] Token retrieved silently on startup: $token");
        if (token != null) {
          await _saveTokenToDatabase(token);
        }
      } catch (e) {
        print("[FCM] Silent token retrieval failed: $e");
      }
      _messaging.onTokenRefresh.listen(_saveTokenToDatabase);
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final user = _supabase.auth.currentUser;
    print("[FCM] Saving token for user: ${user?.id}");
    if (user != null) {
      try {
        await _supabase.from('fcm_tokens').upsert({
          'user_id': user.id,
          'token': token,
          'updated_at': DateTime.now().toIso8601String(),
        });
        print("[FCM] Token saved successfully in Supabase!");
      } catch (e) {
        print("[FCM] Token Registration Failed: $e");
      }
    }
  }

  void _handleIncomingAction(String? title, String? body, String? url) {
    if (!isDashboardStable) {
      print("[FCM] PWA Dashboard not stable yet. Saving pending notification action.");
      _pendingAction = PendingNotificationAction(
        title: title ?? 'Notification Received',
        body: body ?? '',
        url: url,
      );
    } else {
      showNotificationPopup(
        title ?? 'Notification Received',
        body ?? '',
        url,
      );
    }
  }

  void _navigateToUrl(String? url) {
    if (url == null || url.isEmpty) return;
    if (url.startsWith('/')) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) context.go(url);
    } else if (url.startsWith('http')) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  /// Call this from a user gesture (button tap) to request notification permission.
  /// Required on iOS Safari PWAs where auto-prompting is blocked.
  Future<bool> requestPermissionAndRegister() async {
    print("[FCM] requestPermissionAndRegister() called by user gesture...");
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print("[FCM] Permission result: ${settings.authorizationStatus}");

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final vapidKey = kIsWeb
            ? (dotenv.env['FCM_VAPID_KEY'] ??
                'BO0Po4qenG7jOO_N-TIl1Ers3m46ehFoPthGQJ__Wxz9hjfuNtLNu6lqDsM_Cndjw6AADbo_x-E4K3Nu9mr_dI8')
            : null;
        final token = await _messaging.getToken(vapidKey: vapidKey);
        print("[FCM] Token after permission grant: $token");
        if (token != null) {
          await _saveTokenToDatabase(token);
        }
        _messaging.onTokenRefresh.listen(_saveTokenToDatabase);
        return true;
      }
      return false;
    } catch (e) {
      print("[FCM] requestPermissionAndRegister error: $e");
      return false;
    }
  }

  /// Check if notification permission is already granted (no prompt).
  Future<bool> isPermissionGranted() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  void showNotificationPopup(String title, String body, String? url) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassContainer(
            borderRadius: 24,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_active, color: Colors.cyanAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Dismiss', style: TextStyle(color: Colors.white54)),
                        ),
                      ),
                      if (url != null && url.isNotEmpty)
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _navigateToUrl(url);
                            },
                            style: FilledButton.styleFrom(backgroundColor: Colors.cyanAccent),
                            child: const Text('View Action', style: TextStyle(color: Colors.black)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await Hive.initFlutter();
    if (!Hive.isBoxOpen('notifications_box')) {
      await Hive.openBox('notifications_box');
    }

    final data = message.data;
    final userId = data['user_id'];

    if (userId != null) {
      final newNotif = {
        'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'user_id': userId,
        'title': message.notification?.title ?? data['title'] ?? 'No Title',
        'body': message.notification?.body ?? data['body'] ?? 'No Message',
        'type': data['type'] ?? 'system',
        'is_read': false,
        'created_at': (message.sentTime ?? DateTime.now()).toIso8601String(),
        'payload': data.isNotEmpty ? data : null,
      };

      final box = Hive.box('notifications_box');
      final key = 'notifs_$userId';
      final existingData = box.get(key) as String?;
      List<dynamic> list = [];
      if (existingData != null) {
        try {
          list = jsonDecode(existingData);
        } catch (_) {}
      }
      
      if (!list.any((n) => n['id'] == newNotif['id'])) {
        list.insert(0, newNotif);
        if (list.length > 100) list = list.sublist(0, 100);
        await box.put(key, jsonEncode(list));
      }
    }
  } catch (_) {}
}
