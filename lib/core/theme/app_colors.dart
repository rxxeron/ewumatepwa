import 'package:flutter/material.dart';

/// Core palette constants. Prefer `context.ewuColors` in widgets so both
/// dark and light themes stay consistent.
class AppColors {
  // Obsidian & Midnight Neutrals (Dark)
  static const Color primaryNavy = Color(0xFF090C14); // Main Obsidian Scaffold
  static const Color surfaceNavyBlue = Color(0xFF101521); // Primary Bento Surface
  static const Color surfaceElevated = Color(0xFF171E2E); // Raised Card / Sheet

  // Restrained Gen-Z Accents
  static const Color primaryCyan = Color(0xFF22D3EE); // Electric Cyan (Primary Action / Live)
  static const Color secondarySoftBlue = Color(0xFF818CF8); // Soft Indigo (Secondary / Academic)

  // Text
  static const Color primaryText = Color(0xFFF8FAFC);
  static const Color secondaryText = Color(0xFF94A3B8);
  static const Color mutedText = Color(0xFF64748B);

  // Semantic Colors
  static const Color success = Color(0xFF34D399); // Emerald
  static const Color warning = Color(0xFFFBBF24); // Amber
  static const Color error = Color(0xFFF87171); // Coral Red
  static const Color academic = Color(0xFFA78BFA); // Soft Violet
  static const Color info = Color(0xFF38BDF8); // Sky Blue
}
