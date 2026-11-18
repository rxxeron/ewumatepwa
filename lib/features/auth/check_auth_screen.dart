import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/data/data_providers.dart';
import '../../core/data/sync/sync_engine.dart';
import '../../core/models/profile.dart';
import '../../core/widgets/sky_animation.dart';
import '../../core/widgets/animated_startup_cover.dart';
import '../../core/services/tutorial_service.dart';
import 'auth_providers.dart';
import '../../core/repositories/auth_repository.dart' hide authStateProvider;
import '../../core/services/cache_service.dart';

/// Launch gate. Routes from LOCAL data on the first frame when it exists; only a
/// brand-new device (or the first sign-in) waits for the first download.
class CheckAuthScreen extends ConsumerStatefulWidget {
  const CheckAuthScreen({super.key});

  @override
  ConsumerState<CheckAuthScreen> createState() => _CheckAuthScreenState();
}

class _CheckAuthScreenState extends ConsumerState<CheckAuthScreen> {
  bool _navigated = false;
  bool _offline = false;
  StreamSubscription<SyncReport>? _reports;

  void _go(String route) {
    if (_navigated) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(route);
    });
  }

  /// First download for this user on this device: watch the sync result so an
  /// offline first launch shows a retry instead of spinning forever.
  void _watchFirstSync(SyncEngine engine) {
    _reports ??= engine.reports.listen((r) {
      if (mounted) setState(() => _offline = r.offline || r.errors.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _reports?.cancel();
    super.dispose();
  }

  String _routeFor(Profile p) {
    if (p.onboardingStatus == 'pending' || p.onboardingStatus == 'registered' || p.programCode == null) {
      return '/onboarding/profile-setup';
    }
    if (p.onboardingStatus == 'course_history') return '/onboarding/course-history';
    return ''; // complete -> grade blocker / dashboard
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    ref.watch(syncCoordinatorProvider); // starts syncing as soon as a user is known

    Widget body;
    if (uid == null) {
      _go('/login');
      body = const CircularProgressBinding(text: 'Redirecting to login...');
    } else {
      final profile = ref.watch(profileProvider).value;
      final ready = ref.watch(userDataReadyProvider).value ?? false;

      if (profile != null) {
        final route = _routeFor(profile);
        if (route.isNotEmpty) {
          _go(route);
          body = const CircularProgressBinding(text: 'Restoring session...');
        } else {
          body = _GradeBlockerWrapper(onNavigate: _go);
        }
      } else if (ready) {
        // Downloaded, and the server has no profile for this account: new user.
        _go('/onboarding/program');
        body = const CircularProgressBinding(text: 'Setting up your profile...');
      } else {
        final engine = ref.watch(syncEngineProvider);
        if (engine != null) _watchFirstSync(engine);
        body = _offline
            ? _ErrorView(
                message: 'Connect to the internet once to download your data.\nAfter that the app works offline.',
                onRetry: () {
                  setState(() => _offline = false);
                  ref.read(syncCoordinatorProvider)?.schedule(force: true, delay: Duration.zero);
                },
              )
            : const CircularProgressBinding(text: 'Downloading your data...');
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SkyAnimationWidget()),
          Center(child: body),
        ],
      ),
    );
  }
}

// Removed _ProfileCheckWrapper as its logic is now integrated into CheckAuthScreen for Zero-Wait Entry

class _GradeBlockerWrapper extends ConsumerWidget {
  final void Function(String route) onNavigate;
  const _GradeBlockerWrapper({required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradeCheckAsync = ref.watch(requiresGradeEntryProvider);
    debugPrint("[CheckAuth] Phase: Grade Scanning (${gradeCheckAsync.isLoading ? 'SCANNING' : 'DONE'})");

    return gradeCheckAsync.when(
      data: (requiresGrade) {
        if (requiresGrade) {
          onNavigate('/results/grade-entry');
        } else {
          // Check if welcome tour needs to be shown
          _checkWelcomeTourAndNavigate();
        }
        return const CircularProgressBinding(text: 'Preparing Dashboard...');
      },
      error: (err, stack) => _ErrorView(
        message: 'Semester check failed: $err',
        onRetry: () => ref.refresh(requiresGradeEntryProvider),
      ),
      loading: () => const CircularProgressBinding(),
    );
  }

  Future<void> _checkWelcomeTourAndNavigate() async {
    final hasSeenTour = await TutorialService().hasCompletedWelcomeTour();
    if (!hasSeenTour) {
      onNavigate('/onboarding/welcome-tour');
    } else {
      onNavigate('/dashboard');
    }
  }
}

class _ErrorView extends ConsumerWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade900,
              minimumSize: const Size(200, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Local Cache?'),
                  content: const Text('This will wipe all offline data and restart the app. Use this if you are seeing stale information.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true), 
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(cacheServiceProvider).clearAll();
                await ref.read(appDatabaseProvider).clearUserData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared. Restarting...')),
                  );
                  onRetry();
                }
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              minimumSize: const Size(200, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Clear Cache'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout?'),
                  content: const Text('Are you sure you want to log out and try again?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true), 
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/login');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('Logout and Reset'),
          ),
        ],
      ),
    );
  }
}

class CircularProgressBinding extends StatelessWidget {
  final String text;
  const CircularProgressBinding({super.key, this.text = 'Syncing universe...'});

  @override
  Widget build(BuildContext context) {
    return AnimatedStartupCover(statusText: text);
  }
}
