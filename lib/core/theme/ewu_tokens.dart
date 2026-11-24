import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 4pt spacing scale for consistent layout rhythm.
abstract final class EwuSpace {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Standardized corner radii across the app.
abstract final class EwuRadius {
  static const double chip = 8.0;
  static const double card = 16.0;
  static const double sheet = 24.0;
  static const double pill = 999.0;
}

/// Semantic status/category color triplet for consistent badges, chips, and banners.
@immutable
class EwuTone {
  final Color fg;
  final Color bg;
  final Color border;

  const EwuTone({
    required this.fg,
    required this.bg,
    required this.border,
  });
}

/// Six-level typography scale: Sora for display/titles/numbers, Inter for body/metadata.
/// Minimum font size is 12px for readability on mobile screens.
abstract final class EwuText {
  static TextStyle display(Color color, {bool tabular = false}) => GoogleFonts.sora(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.6,
        color: color,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      );

  static TextStyle title(Color color, {bool tabular = false}) => GoogleFonts.sora(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
        color: color,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      );

  static TextStyle headline(Color color, {bool tabular = false}) => GoogleFonts.sora(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.2,
        color: color,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      );

  static TextStyle body(Color color, {FontWeight weight = FontWeight.w400}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: weight,
        height: 1.45,
        color: color,
      );

  static TextStyle label(Color color, {FontWeight weight = FontWeight.w600, bool tabular = false}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: weight,
        height: 1.35,
        letterSpacing: 0.1,
        color: color,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      );

  static TextStyle caption(Color color, {FontWeight weight = FontWeight.w500, bool tabular = false}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: weight,
        height: 1.3,
        letterSpacing: 0.15,
        color: color,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      );
}
