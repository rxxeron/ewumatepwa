import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/supabase_provider.dart';

/// The Session Guardian monitors the Supabase auth state and 
/// ensures that the session is refreshed properly and persistent.
import '../repositories/profile_repository.dart';
import '../services/fcm_service.dart';
import '../services/telemetry_service.dart';

/// The Session Guardian monitors the Supabase auth state and 
/// ensures that the session is refreshed properly and persistent.
final sessionGuardianProvider = Provider<SessionGuardian>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  final fcmService = ref.watch(fcmServiceProvider);
  final guardian = SessionGuardian(supabase, profileRepo, fcmService);
  ref.onDispose(() => guardian.dispose());
  return guardian;
});

class SessionGuardian {
  final SupabaseClient _client;
  final ProfileRepository _profileRepo;
  final FCMService _fcmService;
  StreamSubscription<AuthState>? _subscription;

  SessionGuardian(this._client, this._profileRepo, this._fcmService) {
    _init();
  }

  /// User ids already handled in this app run (app-open recorded, token checked).
  final Set<String> _handled = {};

  /// Once per app run and per newly signed-in user — not on every
  /// initialSession / hourly tokenRefreshed event as before.
  void _onUserPresent(String userId) {
    if (!_handled.add(userId)) return;
    _profileRepo.recordActivity(userId);
    _fcmService.syncToken();
    TelemetryService.identifyUser(
      userId,
      email: _client.auth.currentUser?.email,
    );
  }

  void _init() {
    final activeSession = _client.auth.currentSession;
    if (activeSession?.user != null) {
      _onUserPresent(activeSession!.user.id);
    }

    _subscription = _client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (kDebugMode) {
        print('[SessionGuardian] Auth Event: ${event.name} (${session != null ? 'session' : 'no session'})');
      }

      if (session?.user != null && event == AuthChangeEvent.signedIn) {
        _onUserPresent(session!.user.id);
      }
      if (event == AuthChangeEvent.signedOut) {
        _handled.clear();
        TelemetryService.resetUser();
      }

      switch (event) {
        case AuthChangeEvent.signedIn:
          if (kDebugMode) print('[SessionGuardian] ✅ User signed in. Session secured.');
          break;
        case AuthChangeEvent.tokenRefreshed:
          if (kDebugMode) print('[SessionGuardian] 🔄 Token refreshed successfully.');
          break;
        case AuthChangeEvent.signedOut:
          if (kDebugMode) print('[SessionGuardian] ⚠️ User signed out event detected.');
          break;
        case AuthChangeEvent.userUpdated:
          if (kDebugMode) print('[SessionGuardian] 👤 Profile/User data updated.');
          break;
        case AuthChangeEvent.passwordRecovery:
          if (kDebugMode) print('[SessionGuardian] 🔑 Password recovery initiated.');
          break;
        case AuthChangeEvent.initialSession:
          if (kDebugMode) print('[SessionGuardian] 🏁 Initial session loaded: ${session != null}');
          break;
        case AuthChangeEvent.mfaChallengeVerified:
          if (kDebugMode) print('[SessionGuardian] 🔐 MFA Challenge Verified.');
          break;
        default:
          break;
      }
    }, onError: (error) {
      if (kDebugMode) print('[SessionGuardian] ❌ Auth Stream Error: $error');
    });
  }

  /// Proactively refresh the session if needed
  Future<void> refreshNow() async {
    try {
      await _client.auth.refreshSession();
      if (kDebugMode) print('[SessionGuardian] Manual refresh triggered.');
    } catch (e) {
      if (kDebugMode) print('[SessionGuardian] Manual refresh failed: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
