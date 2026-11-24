import 'package:flutter/material.dart';
import 'glass_kit.dart';
import '../services/tutorial_service.dart';
import '../theme/ewu_theme_extension.dart';
import '../theme/ewu_tokens.dart';

class OnboardingOverlay extends StatelessWidget {
  final String featureKey;
  final List<OnboardingStep> steps;
  final VoidCallback? onComplete;

  const OnboardingOverlay({
    super.key,
    required this.featureKey,
    required this.steps,
    this.onComplete,
  });

  static void show({
    required BuildContext context,
    required String featureKey,
    required List<OnboardingStep> steps,
    VoidCallback? onComplete,
  }) async {
    final tutorialService = TutorialService();
    if (await tutorialService.hasSeen(featureKey)) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => OnboardingOverlay(
        featureKey: featureKey,
        steps: steps,
        onComplete: onComplete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingDialogBody(
      featureKey: featureKey,
      steps: steps,
      onComplete: onComplete,
    );
  }
}

class _OnboardingDialogBody extends StatefulWidget {
  final String featureKey;
  final List<OnboardingStep> steps;
  final VoidCallback? onComplete;

  const _OnboardingDialogBody({
    required this.featureKey,
    required this.steps,
    this.onComplete,
  });

  @override
  State<_OnboardingDialogBody> createState() => _OnboardingDialogBodyState();
}

class _OnboardingDialogBodyState extends State<_OnboardingDialogBody> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.ewuColors;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassContainer(
            height: 440,
            width: double.infinity,
            borderRadius: 24,
            color: colors.surface,
            opacity: 0.94,
            borderColor: colors.borderSubtle,
            blur: 15,
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentStep = idx),
                    itemCount: widget.steps.length,
                    itemBuilder: (context, index) {
                      final step = widget.steps[index];
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(step.icon, size: 56, color: colors.accent),
                            const SizedBox(height: 24),
                            Text(
                              step.title,
                              textAlign: TextAlign.center,
                              style: EwuText.title(colors.textPrimary),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              step.description,
                              textAlign: TextAlign.center,
                              style: EwuText.body(colors.textSecondary),
                            ),
                          ],
                        ),
                      );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 32, left: 32, right: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Step Indicators
                        Row(
                          children: List.generate(
                            widget.steps.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentStep == index
                                    ? context.ewuColors.accent
                                    : context.ewuColors.borderSubtle,
                              ),
                            ),
                          ),
                        ),
                        // Action Button
                        ElevatedButton(
                          onPressed: () async {
                            if (_currentStep < widget.steps.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              await TutorialService().markAsSeen(widget.featureKey);
                              if (context.mounted) Navigator.pop(context);
                              widget.onComplete?.call();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.ewuColors.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: Text(
                            _currentStep < widget.steps.length - 1 ? "Next" : "Got it!",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (widget.steps.length > 1 && _currentStep < widget.steps.length - 1) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          await TutorialService().markAsSeen(widget.featureKey);
                          if (context.mounted) Navigator.pop(context);
                          widget.onComplete?.call();
                        },
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: context.ewuColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final IconData icon;

  const OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}
