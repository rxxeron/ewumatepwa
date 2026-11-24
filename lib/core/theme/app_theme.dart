import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ewu_theme_extension.dart';
import 'ewu_tokens.dart';

class AppTheme {
  static ThemeData get darkTheme => _buildTheme(EwuColors.dark);
  static ThemeData get lightTheme => _buildTheme(EwuColors.light);

  static ThemeData _buildTheme(EwuColors c) {
    final base = c.isDark ? ThemeData.dark() : ThemeData.light();
    final interBase = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
      textTheme: interBase.copyWith(
        displaySmall: EwuText.display(c.textPrimary),
        headlineMedium: EwuText.title(c.textPrimary),
        titleMedium: EwuText.headline(c.textPrimary),
        bodyMedium: EwuText.body(c.textPrimary),
        labelLarge: EwuText.label(c.textPrimary),
        bodySmall: EwuText.caption(c.textSecondary),
      ),
      colorScheme: (c.isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: c.accent,
        secondary: c.accentSecondary,
        surface: c.surface,
        onSurface: c.textPrimary,
        onSurfaceVariant: c.textSecondary,
        error: c.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.textPrimary),
        titleTextStyle: EwuText.title(c.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EwuRadius.card),
          side: BorderSide(color: c.borderSubtle, width: 1),
        ),
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceRaised,
        selectedColor: c.accent,
        disabledColor: Colors.transparent,
        labelStyle: EwuText.label(c.textPrimary),
        secondaryLabelStyle: EwuText.label(c.isDark ? c.bg : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EwuRadius.chip)),
        side: BorderSide(color: c.borderSubtle, width: 1),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(EwuRadius.sheet)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceRaised,
        hintStyle: EwuText.body(c.textMuted),
        prefixIconColor: c.textSecondary,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EwuRadius.card),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EwuRadius.card),
          borderSide: BorderSide(color: c.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EwuRadius.card),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.25),
        selectionHandleColor: c.accent,
      ),
    );
  }
}
