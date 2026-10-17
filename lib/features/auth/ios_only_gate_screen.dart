import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/pwa_service.dart';
import '../../core/widgets/glass_kit.dart';

class IosOnlyGateScreen extends ConsumerStatefulWidget {
  const IosOnlyGateScreen({super.key});

  @override
  ConsumerState<IosOnlyGateScreen> createState() => _IosOnlyGateScreenState();
}

class _IosOnlyGateScreenState extends ConsumerState<IosOnlyGateScreen> {
  @override
  Widget build(BuildContext context) {
    final pwaState = ref.watch(pwaControllerProvider);

    // If suddenly granted access (e.g. query param detected or bypassed), forward immediately
    if (pwaState.hasAccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
    }

    return FullGradientScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Device Icon Badge
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF0077FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.apple_rounded,
                      size: 54,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Pill Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'EXCLUSIVE FOR IOS & IPADOS',
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF00E5FF),
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Title
                Text(
                  'EWUmate Web Edition',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Description
                Text(
                  'The web application is tailored specifically for Apple Safari and iOS devices. '
                  'For Android and PC users, we offer dedicated high-performance alternatives.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 32),

                // 5. Google Play Android Recommendation Card
                GlassContainer(
                  borderRadius: 20,
                  opacity: 0.08,
                  borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.android_rounded,
                              color: Color(0xFF10B981),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Using an Android Device?',
                                  style: GoogleFonts.sora(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Get widgets, reminders & offline mode.',
                                  style: GoogleFonts.sora(
                                    fontSize: 11,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            const playStoreUrl =
                                'https://play.google.com/store/apps/details?id=com.rxxeron.ewumate';
                            final uri = Uri.parse(playStoreUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.shop_rounded, size: 20),
                          label: Text(
                            'Open on Google Play Store',
                            style: GoogleFonts.sora(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: const Color(0xFF071426),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
