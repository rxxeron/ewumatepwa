import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static String _env(String key) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.maybeGet(key) ?? '';
      }
    } catch (_) {}
    return '';
  }

  static String get getSupabaseUrl => _env('SUPABASE_URL');
  static String get getSupabaseAnonKey => _env('SUPABASE_ANON_KEY');
  static String get getAzureFunctionUrl {
    final val = _env('AZURE_FUNCTION_URL');
    return val.isNotEmpty ? val : 'https://ewumate-parser-api.azurewebsites.net';
  }
  static String get getGoogleWebClientId {
    final val = _env('GOOGLE_WEB_CLIENT_ID');
    return val.isNotEmpty ? val : '561956344734-ulqeqls9u4h1hmpec41l9lufk336a9ga.apps.googleusercontent.com';
  }
  static String get getPosthogApiKey {
    final val = _env('POSTHOG_API_KEY');
    return val.isNotEmpty ? val : 'phc_yyBXNRaiyqLStVyYB5xh69TpSZQL6R2YveZXNH4ntAiy';
  }
  static String get getPosthogHost {
    final val = _env('POSTHOG_HOST');
    return val.isNotEmpty ? val : 'https://us.i.posthog.com';
  }
}

class SupabaseConfig {
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      if (kDebugMode) debugPrint('[SupabaseConfig] .env load notice: $e');
    }

    final url = AppConfig.getSupabaseUrl;
    final anonKey = AppConfig.getSupabaseAnonKey;

    if (url.isEmpty || anonKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('[SupabaseConfig] Warning: SUPABASE_URL or SUPABASE_ANON_KEY is empty in .env');
      }
    }

    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
    );
  }
}
