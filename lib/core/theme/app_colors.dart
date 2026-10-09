import 'package:flutter/material.dart';

/// RVMI Media's purple brand palette, derived from `RVMI-MEDIA/color-inspo.jpg`.
/// A deep, confident purple (not pastel) carries the "church app, not a
/// social network" feel while still looking modern.
class AppColors {
  const AppColors._();

  // Brand scale — light mode.
  static const brand50 = Color(0xFFF5F3FF);
  static const brand100 = Color(0xFFEDE9FE);
  static const brand200 = Color(0xFFDDD6FE);
  static const brand300 = Color(0xFFC4B5FD);
  static const brand400 = Color(0xFFA78BFA);
  static const brand500 = Color(0xFF7C3AED); // primary / accent
  static const brand600 = Color(0xFF6D28D9); // hover / pressed
  static const brand700 = Color(0xFF5B21B6);
  static const brand800 = Color(0xFF4C1D95);
  static const brand900 = Color(0xFF2E1065);

  static const navActiveLight = brand600;
  static const navActiveDark = brand300;

  /// Scaffold wash — near-white with a whisper of violet.
  static const scaffoldWash = Color(0xFFFBFAFF);

  // Status colors.
  static const success = Color(0xFF22C55E);
  static const successDark = Color(0xFF16A34A);
  static const error = Color(0xFFEF4444);
  static const errorDark = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);
  static const warningDark = Color(0xFFB45309);

  // Gold accent — pulled from the RVMI logo, used sparingly (badges, the
  // "auto-tagged" chip indicator) so it reads as a deliberate highlight.
  static const gold = Color(0xFFC9A227);

  // Neutral surfaces — light mode.
  static const surfaceBase = Color(0xFFF9FAFB);
  static const surfaceAlt = Color(0xFFFFFFFF);
  static const textDefault = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);

  // Neutral surfaces — dark mode.
  static const surfaceBaseDark = Color(0xFF15121F);
  static const surfaceAltDark = Color(0xFF201B2E);
  static const textDefaultDark = Color(0xFFE5E7EB);
  static const textSecondaryDark = Color(0xFF9CA3AF);
  static const borderDark = Color(0xFF362F47);
  static const borderStrongDark = Color(0xFF4B4160);

  // Glass tokens, used only for hero/sheet surfaces.
  static const glassBg = Color(0x59FFFFFF);
  static const glassBgStrong = Color(0x6BFFFFFF);
  static const glassBorder = Color(0xA6C4B5FD);
  static const glassBgDark = Color(0x8C15121F);
  static const glassBorderDark = Color(0x597C3AED);
}
