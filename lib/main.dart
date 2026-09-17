import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/services/cache_service.dart';
import 'core/services/fcm_service.dart';
import 'firebase_options.dart';
import 'core/providers/session_guardian.dart';
import 'core/services/update_service.dart';
import 'core/config/url_strategy_config.dart'
    if (dart.library.html) 'core/config/url_strategy_config_web.dart';
import 'core/theme/app_theme.dart';
import 'core/repositories/auth_repository.dart';

void main() async {
  configureUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();


  // Initialize Cache Service (Hive), Firebase, and Supabase in parallel
  final cacheService = CacheService();
  
  try {
    await Future.wait([
      cacheService.init(),
      () async {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('Firebase init error: $e');
        }
      }(),
      SupabaseConfig.initialize().catchError((e) {
        if (kDebugMode) debugPrint('Supabase init error: $e');
      }),
    ]);
  } catch (e) {
    if (kDebugMode) debugPrint('Parallel initialization error: $e');
  }

  // Register top-level FCM background message handler on mobile platforms
  if (!kIsWeb) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase background handler registration error: $e');
    }
  }

  runApp(
    ProviderScope(
      // Provide the initialized cache service instance synchronously to the remaining app
      overrides: [
        cacheServiceProvider.overrideWithValue(cacheService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize Session Guardian
    ref.read(sessionGuardianProvider);

    // Initialize PWA / Service Worker update listener
    if (kIsWeb) {
      ref.read(updateListenerProvider);
    }
    
    // Initialize FCM (Web and Mobile): setup handlers and listeners
    ref.read(fcmServiceProvider).initialize().catchError((err) {
      if (kDebugMode) debugPrint('FCM Init Error: $err');
    });

    ref.listen(authStateProvider, (previous, next) {
      final session = next.value?.session;
      if (session != null) {
        final user = session.user;
        ref.read(authRepositoryProvider).ensureProfileExists(user).catchError((err) {
          if (kDebugMode) debugPrint('Ensure profile error: $err');
        });
        ref.read(fcmServiceProvider).syncToken().catchError((err) {
          if (kDebugMode) debugPrint('FCM Sync Error: $err');
        });
      }
    });
    
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'EWUmate',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
