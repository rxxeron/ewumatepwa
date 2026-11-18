import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/repos/local_writer.dart';
import '../repositories/active_semester_repository.dart';
import '../../features/auth/auth_providers.dart';

part 'feature_flag_provider.g.dart';

/// Controls whether ads/banners are enabled for a given screen.
/// Currently disabled throughout the app.
final isAdEnabledForProvider = Provider.family<bool, String>((ref, screenName) {
  return false;
});

@riverpod
Future<bool> isAdvisingOpen(Ref ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return false;

  final repo = ref.watch(activeSemesterRepositoryProvider);
  try {
    String track = profile.track ?? profile.semesterType;
    final res = await repo.getActiveSemester(track);
    return res['is_advising_open'] ?? false;
  } catch (_) {}
  return false;
}

@riverpod
Future<bool> isNextSemesterOpen(Ref ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return false;

  final repo = ref.watch(activeSemesterRepositoryProvider);
  try {
    String track = profile.track ?? profile.semesterType;
    final res = await repo.getActiveSemester(track);
    return res['is_next_semester_open'] ?? false;
  } catch (_) {}
  return false;
}

/// Fetches the admin-controlled promo banner config from app_config.
/// Expected JSON shape:
/// {
///   "is_active": true,
///   "image_url": "https://...",
///   "link_url": "https://...",
///   "title": "Optional label"
/// }
/// app_config value by key from the local database (scope `reference`, pulled
/// when an admin changes it) — no network query per screen.
Future<Object?> _localConfig(Ref ref, String key) async {
  final rows = await ref.watch(localRowsProvider(('app_config', null)).future);
  final v = rows.where((r) => r['key'] == key).firstOrNull?['value'];
  if (v is String) {
    try {
      return jsonDecode(v);
    } catch (_) {}
  }
  return v;
}

final promoBannerProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final val = await _localConfig(ref, 'promo_banner');
  return val is Map ? Map<String, dynamic>.from(val) : null;
});

final isDonationPopupEnabledProvider = FutureProvider<bool>((ref) async {
  final val = await _localConfig(ref, 'donation_popup');
  return val is Map && val['is_active'] == true;
});