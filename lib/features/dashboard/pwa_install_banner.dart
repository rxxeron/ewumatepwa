import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glass_kit/glass_kit.dart';
import '../../core/services/pwa_service.dart';

class PwaInstallBanner extends ConsumerWidget {
  const PwaInstallBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pwaState = ref.watch(pwaControllerProvider);

    // If already installed or running as standalone, hide the prompt
    if (pwaState.isStandalone) {
      return const SizedBox.shrink();
    }

    final bool showAndroidInstall = pwaState.isInstallable;
    final bool showIOSInstall = pwaState.isIOS;

    // If neither is installable (e.g. unsupported desktop browser, already installed), hide
    if (!showAndroidInstall && !showIOSInstall) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: GlassContainer.clearGlass(
        height: 140,
        width: double.infinity,
        borderRadius: BorderRadius.circular(24),
        borderWidth: 1.5,
        borderColor: Colors.white.withOpacity(0.12),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B).withOpacity(0.65),
            const Color(0xFF0F172A).withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      showIOSInstall ? 'Add EWUMate to Home Screen' : 'EWUMate App Ready',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      showIOSInstall
                          ? 'Tap the Share icon (📤) in Safari and select "Add to Home Screen" to install.'
                          : 'Install EWUMate on your home screen for quick, offline routine & grade tracking.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (showAndroidInstall)
                ElevatedButton(
                  onPressed: () async {
                    final success = await ref.read(pwaControllerProvider.notifier).installApp();
                    if (context.mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thank you for installing EWUMate PWA!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37), // Premium Gold
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  child: const Text(
                    'Install',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              else if (showIOSInstall)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.ios_share_rounded,
                    color: Color(0xFFD4AF37),
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
