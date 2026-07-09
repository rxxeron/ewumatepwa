import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/services/cache_service.dart';
import 'core/services/fcm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'core/providers/session_guardian.dart';
import 'core/repositories/auth_repository.dart';
import 'core/services/update_service.dart';
import 'core/widgets/access_restricted_screen.dart';
import 'core/config/url_strategy_config.dart'
    if (dart.library.html) 'core/config/url_strategy_config_web.dart';

/// Whether Firebase was successfully initialized (false on web).
bool _firebaseInitialized = false;
void main() async {
  configureUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Cache Service (Hive) before running the app
  final cacheService = CacheService();
  await cacheService.init();

  // Initialize Firebase across all supported platforms (Mobile & Web PWA)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseInitialized = true;
    print('[Firebase] Initialization successful!');
  } catch (e) {
    print('[Firebase] Initialization failed error: $e');
  }

  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    if (kDebugMode) debugPrint('Supabase init error: $e');
  }

  // FCM setup moved to MyApp for better Riverpod integration

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
    
    // Initialize FCM when the user is logged in
    print('[FCM] Checking initialization condition: _firebaseInitialized = $_firebaseInitialized');
    if (_firebaseInitialized) {
      // 1. If already logged in on startup, initialize FCM immediately
      final currentUser = ref.read(authRepositoryProvider).currentUser;
      print('[FCM] currentUser on startup: ${currentUser?.id}');
      if (currentUser != null) {
        try {
          ref.read(fcmServiceProvider).initialize().catchError((err) {
            print('[FCM] Init Error on startup: $err');
          });
        } catch (e) {
          print('[FCM] provider creation failed on startup: $e');
        }
      }

      // 2. Listen to future auth changes
      ref.listen(authStateProvider, (previous, next) {
        final event = next.value?.event;
        print('[FCM] authStateProvider event received: $event');
        if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) {
          try {
            ref.read(fcmServiceProvider).initialize().catchError((err) {
              print('[FCM] Init Error on change: $err');
            });
          } catch (e) {
            print('[FCM] provider creation failed on change: $e');
          }
        }
      });
    }
    
    final router = ref.watch(appRouterProvider);

    // Block non-Apple devices on PWA web (bypass in local debug mode)
    if (kIsWeb && !kDebugMode) {
      final isApple = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
      if (!isApple) {
        return MaterialApp(
          title: 'Access Restricted',
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0F172A),
          ),
          debugShowCheckedModeBanner: false,
          home: const AccessRestrictedScreen(),
        );
      }
    }

    return MaterialApp.router(
      title: 'EWUmate',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B).withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
