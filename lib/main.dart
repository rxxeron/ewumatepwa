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

Future<void> _bootloader(CacheService cache) async {
  // 1. Cache Layer
  try { 
    await cache.init(); 
  } catch (e) { 
    if (kDebugMode) debugPrint('[Boot] Cache init error: $e'); 
  }
  
  // 2. Firebase Layer (Gracefully skipped on Web to prevent JS Object crashes)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      if (kDebugMode) debugPrint('[Boot] Firebase init error: $e');
    }
  } else {
    if (kDebugMode) debugPrint('[Boot] Web detected: Bypassing Firebase init.');
  }

  // 3. Supabase Layer
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    if (kDebugMode) debugPrint('[Boot] Supabase init error: $e');
  }
}

void main() async {
  configureUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // Protect against release-mode white screen if any widget error occurs
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF071426),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded, color: Color(0xFF19D9F5), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Starting EWUmate...',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  kDebugMode ? details.exceptionAsString() : 'Connecting services, please wait...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  final cacheService = CacheService();
  await _bootloader(cacheService);

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
    
    // Initialize FCM safely post-frame so widget build is never blocked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(fcmServiceProvider).initialize().catchError((err) {
          if (kDebugMode) debugPrint('FCM Init Error: $err');
        });
      } catch (e) {
        if (kDebugMode) debugPrint('FCM post-frame init notice: $e');
      }
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
