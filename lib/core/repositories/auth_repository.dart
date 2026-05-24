import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../providers/supabase_provider.dart';
import '../services/cache_service.dart';
import '../models/profile.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final SupabaseClient _supabase;
  final CacheService _cache;

  AuthRepository(this._supabase, this._cache);

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
      await _cache.saveLastUserId(res.user!.id);
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
    await _cache.clearAll();
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      // If the JWT is already invalid/expired, Supabase auth might throw.
      // We still want to clear the local session so the user isn't stuck.
      // So we catch and ignore it, allowing the logout process to finish locally.
    }
  }

  // Google Sign In - Popup-based on web to preserve standalone PWA context, dynamic redirect/native deep link on mobile
  Future<bool> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '561956344734-ulqeqls9u4h1hmpec41l9lufk336a9ga.apps.googleusercontent.com';
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: webClientId,
        );

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          debugPrint('[AuthRepository] Google Sign-In aborted by user.');
          return false;
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;

        if (idToken == null) {
          throw const AuthException('Could not retrieve Google ID Token.');
        }

        final response = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        if (response.user != null) {
          await _cache.saveLastUserId(response.user!.id);
        }
        return true;
      } catch (e, stack) {
        debugPrint('[AuthRepository] Google Web Sign-In failed: $e\n$stack');
        rethrow;
      }
    } else {
      // Mobile native deep-link callback
      return await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.ewumate://login-callback',
      );
    }
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  final cache = ref.watch(cacheServiceProvider);
  return AuthRepository(ref.watch(supabaseClientProvider), cache);
}

@riverpod
Stream<AuthState> authState(AuthStateRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}

@riverpod
User? currentUser(CurrentUserRef ref) {
  // Watch auth state changes to make this provider reactive
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? Supabase.instance.client.auth.currentUser;
}
