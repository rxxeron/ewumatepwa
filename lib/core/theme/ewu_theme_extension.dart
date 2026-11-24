import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'ewu_tokens.dart';

@immutable
class EwuColors extends ThemeExtension<EwuColors> {
  final Color primaryNavy;
  final Color surfaceNavyBlue;
  final Color surfaceElevated;
  final Color primaryCyan;
  final Color secondarySoftBlue;
  final Color borderSubtle;
  final Color borderFocus;
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color success;
  final Color warning;
  final Color error;
  final Color academic;
  final Color info;
  final bool isDark;

  // Role-based semantic aliases (preferred for new/migrated code)
  Color get bg => primaryNavy;
  Color get surface => surfaceNavyBlue;
  Color get surfaceRaised => surfaceElevated;
  Color get accent => primaryCyan;
  Color get accentSecondary => secondarySoftBlue;
  Color get textPrimary => primaryText;
  Color get textSecondary => secondaryText;
  Color get textTertiary => tertiaryText;
  Color get textMuted => tertiaryText;
  Color get accentAlert => error;
  Color get accentAmber => warning;
  Color get surfaceCardNavy => surfaceElevated;

  EwuTone get accentTone => _tone(primaryCyan);
  EwuTone get successTone => _tone(success);
  EwuTone get warningTone => _tone(warning);
  EwuTone get dangerTone => _tone(error);
  EwuTone get infoTone => _tone(info);
  EwuTone get academicTone => _tone(academic);

  /// Six fixed contrast-checked category colors for courses & task types.
  List<Color> get categoryColors => [
        primaryCyan,
        secondarySoftBlue,
        success,
        warning,
        academic,
        info,
      ];

  EwuTone _tone(Color base) => EwuTone(
        fg: base,
        bg: base.withValues(alpha: isDark ? 0.14 : 0.10),
        border: base.withValues(alpha: isDark ? 0.28 : 0.24),
      );

  const EwuColors({
    required this.primaryNavy,
    required this.surfaceNavyBlue,
    required this.surfaceElevated,
    required this.primaryCyan,
    required this.secondarySoftBlue,
    required this.borderSubtle,
    required this.borderFocus,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.success,
    required this.warning,
    required this.error,
    required this.academic,
    required this.info,
    required this.isDark,
  });

  static const dark = EwuColors(
    primaryNavy: AppColors.primaryNavy, // #090C14 Obsidian
    surfaceNavyBlue: AppColors.surfaceNavyBlue, // #101521
    surfaceElevated: AppColors.surfaceElevated, // #171E2E
    primaryCyan: AppColors.primaryCyan, // #22D3EE
    secondarySoftBlue: AppColors.secondarySoftBlue, // #818CF8
    borderSubtle: Color(0x14FFFFFF), // white 8% hairline
    borderFocus: AppColors.primaryCyan,
    primaryText: AppColors.primaryText, // #F8FAFC
    secondaryText: AppColors.secondaryText, // #94A3B8
    tertiaryText: AppColors.mutedText, // #64748B
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    academic: AppColors.academic,
    info: AppColors.info,
    isDark: true,
  );

  static const light = EwuColors(
    primaryNavy: Color(0xFFF6F8FC), // Cool Alabaster
    surfaceNavyBlue: Color(0xFFFFFFFF), // Pure White Bento Card
    surfaceElevated: Color(0xFFEEF2F8), // Soft Slate Surface
    primaryCyan: Color(0xFF0891B2), // High-contrast Deep Cyan
    secondarySoftBlue: Color(0xFF4F46E5), // Crisp Indigo
    borderSubtle: Color(0x120F172A), // Slate 7% hairline
    borderFocus: Color(0xFF0891B2),
    primaryText: Color(0xFF0F172A), // Slate 900
    secondaryText: Color(0xFF475569), // Slate 600
    tertiaryText: Color(0xFF64748B), // Slate 500
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    academic: Color(0xFF7C3AED),
    info: Color(0xFF0284C7),
    isDark: false,
  );

  @override
  EwuColors copyWith({
    Color? primaryNavy,
    Color? surfaceNavyBlue,
    Color? surfaceElevated,
    Color? primaryCyan,
    Color? secondarySoftBlue,
    Color? borderSubtle,
    Color? borderFocus,
    Color? primaryText,
    Color? secondaryText,
    Color? tertiaryText,
    Color? success,
    Color? warning,
    Color? error,
    Color? academic,
    Color? info,
    bool? isDark,
  }) {
    return EwuColors(
      primaryNavy: primaryNavy ?? this.primaryNavy,
      surfaceNavyBlue: surfaceNavyBlue ?? this.surfaceNavyBlue,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      primaryCyan: primaryCyan ?? this.primaryCyan,
      secondarySoftBlue: secondarySoftBlue ?? this.secondarySoftBlue,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderFocus: borderFocus ?? this.borderFocus,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      academic: academic ?? this.academic,
      info: info ?? this.info,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  EwuColors lerp(ThemeExtension<EwuColors>? other, double t) {
    if (other is! EwuColors) return this;
    return EwuColors(
      primaryNavy: Color.lerp(primaryNavy, other.primaryNavy, t) ?? primaryNavy,
      surfaceNavyBlue: Color.lerp(surfaceNavyBlue, other.surfaceNavyBlue, t) ?? surfaceNavyBlue,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t) ?? surfaceElevated,
      primaryCyan: Color.lerp(primaryCyan, other.primaryCyan, t) ?? primaryCyan,
      secondarySoftBlue: Color.lerp(secondarySoftBlue, other.secondarySoftBlue, t) ?? secondarySoftBlue,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t) ?? borderSubtle,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t) ?? borderFocus,
      primaryText: Color.lerp(primaryText, other.primaryText, t) ?? primaryText,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t) ?? secondaryText,
      tertiaryText: Color.lerp(tertiaryText, other.tertiaryText, t) ?? tertiaryText,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
      academic: Color.lerp(academic, other.academic, t) ?? academic,
      info: Color.lerp(info, other.info, t) ?? info,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension EwuThemeContext on BuildContext {
  EwuColors get ewuColors => Theme.of(this).extension<EwuColors>() ?? EwuColors.dark;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
