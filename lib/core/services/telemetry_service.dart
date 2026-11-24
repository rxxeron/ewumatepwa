import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/supabase_config.dart';

/// Centralized PostHog telemetry & error-tracking service for EWUmate PWA.
class TelemetryService {
  TelemetryService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    final apiKey = AppConfig.getPosthogApiKey.trim();
    if (apiKey.isEmpty) return;

    try {
      final config = PostHogConfig(apiKey)
        ..host = AppConfig.getPosthogHost
        ..captureApplicationLifecycleEvents = true
        ..personProfiles = PostHogPersonProfiles.identifiedOnly
        ..debug = kDebugMode;

      config.errorTrackingConfig
        ..captureFlutterErrors = true
        ..capturePlatformDispatcherErrors = true
        ..captureIsolateErrors = !kIsWeb
        ..inAppIncludes.addAll(['ewumate', 'ewumate_pwa']);

      await Posthog().setup(config);
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Telemetry] PostHog init failed: $e');
      }
    }
  }

  static Future<void> identifyUser(
    String userId, {
    String? email,
    Map<String, Object>? properties,
  }) async {
    if (!_initialized || userId.isEmpty) return;
    try {
      final userProps = <String, Object>{
        'platform': kIsWeb ? 'web_pwa' : defaultTargetPlatform.name,
        if (email != null && email.isNotEmpty) 'email': email,
        ...?properties,
      };
      await Posthog().identify(
        userId: userId,
        userProperties: userProps,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Telemetry] identify failed: $e');
    }
  }

  static Future<void> resetUser() async {
    if (!_initialized) return;
    try {
      await Posthog().reset();
    } catch (e) {
      if (kDebugMode) debugPrint('[Telemetry] reset failed: $e');
    }
  }

  static Future<void> trackEvent(
    String eventName, {
    Map<String, Object>? properties,
  }) async {
    if (!_initialized) return;
    try {
      await Posthog().capture(
        eventName: eventName,
        properties: {
          'platform': kIsWeb ? 'web_pwa' : defaultTargetPlatform.name,
          ...?properties,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Telemetry] trackEvent failed: $e');
    }
  }

  static Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, Object>? extra,
  }) async {
    if (!_initialized) return;
    try {
      await Posthog().captureException(
        error: error,
        stackTrace: stackTrace,
        properties: {
          'platform': kIsWeb ? 'web_pwa' : defaultTargetPlatform.name,
          if (context != null && context.isNotEmpty) 'context': context,
          ...?extra,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Telemetry] recordError failed: $e');
    }
  }
}
