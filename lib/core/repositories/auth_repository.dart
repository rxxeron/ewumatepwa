import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/supabase_provider.dart';
import '../services/cache_service.dart';
import '../data/data_providers.dart';
import '../models/profile.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final SupabaseClient _supabase;
  final CacheService _cache;

  /// Local cleanup run before the session ends (drop the user's local data).
  final Future<void> Function()? _beforeSignOut;

  AuthRepository(this._supabase, this._cache, [this._beforeSignOut]);

  // Observable stream of the current Auth state
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Get the current user
  User? get currentUser => _supabase.auth.currentUser;

  // Sign up with Email and Password
  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  // Sign in with Email and Password
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final res = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user != null) {
      await ensureProfileExists(res.user!);
    }
    return res;
  }

  // Alias for compatibility
  Future<AuthResponse> signIn(String email, String password) => 
    signInWithEmailPassword(email: email, password: password);

  // Get Profile
  Future<Profile?> getProfile(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromJson(response);
  }

  // Send a Magic Link
  Future<void> signInWithOtp({required String email}) async {
    await _supabase.auth.signInWithOtp(email: email);
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _beforeSignOut?.call();
    } catch (_) {}
    try {
      await _cache.clearAll();
    } catch (_) {}
    try {
      await _supabase.auth.signOut().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Global sign-out failed (offline, expired JWT, or timeout): clear local session anyway.
      try {
        await _supabase.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
    }
  }

  // Ensure profile exists immediately after login
  Future<void> ensureProfileExists(User user) async {
    try {
      final existingProfile = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        final fullName = user.userMetadata?['full_name'] ?? 
                         user.userMetadata?['name'] ?? 
                         user.userMetadata?['displayName'] ?? 
                         'New Student';
        
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'full_name': fullName,
          'nickname': fullName.toString().split(' ').first,
          'photo_url': user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
          'onboarding_status': 'registered',
        });
      }
      // Persistence: Save identity to local cache for Zero-Wait entry
      await _cache.saveLastUserId(user.id);
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthRepository] ensureProfileExists error: $e');
    }
  }

  // Google Sign In
  Future<AuthResponse?> signInWithGoogle() async {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      String redirectUrl;
      final segments = Uri.base.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty && segments.first == 'ewumatepwa') {
        redirectUrl = '$origin/ewumatepwa/';
      } else {
        redirectUrl = '$origin/';
      }

      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
      return null;
    }

    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    );

    // Force the account picker
    await googleSignIn.signOut();
    final googleUser = await googleSignIn.authenticate();

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) throw 'No ID Token found.';

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );

    // Ensure profile exists immediately after login
    final user = response.user;
    if (user != null) {
      await ensureProfileExists(user);
    }

    return response;
  }

}

@riverpod
AuthRepository authRepository(Ref ref) {
  final cache = ref.watch(cacheServiceProvider);
  return AuthRepository(ref.watch(supabaseClientProvider), cache, () async {
    try {
      await ref.read(syncCoordinatorProvider)?.unregisterPush().timeout(const Duration(seconds: 3));
    } catch (_) {}
    await ref.read(appDatabaseProvider).clearUserData();
  });
}

@riverpod
Stream<AuthState> authState(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}

@riverpod
User? currentUser(Ref ref) {
  // Watch auth state changes to make this provider reactive
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? Supabase.instance.client.auth.currentUser;
}
