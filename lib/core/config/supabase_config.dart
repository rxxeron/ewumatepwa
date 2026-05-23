import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // Fail silently: .env is missing/404, we will use hardcoded web fallbacks
      // which are perfectly safe for client-side execution.
    }

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://jwygjihrbwxhehijldiz.supabase.co';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp3eWdqaWhyYnd4aGVoaWpsZGl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExMDQxNzQsImV4cCI6MjA4NjY4MDE3NH0.zQc3dq53HBpMeN0rbJA9soF0oYhl7de1_sNnB_9JPoM';

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
