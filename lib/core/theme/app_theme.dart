import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// RVMI Media's Material 3 theme. Deliberately calm and uncluttered —
/// the content (photos/videos) should be the loudest thing on screen.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand500,
      brightness: Brightness.light,
      primary: AppColors.brand600,
      onPrimary: Colors.white,
      surface: AppColors.surfaceAlt,
      error: AppColors.error,
    );

    return _base(colorScheme);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand500,
      brightness: Brightness.dark,
      primary: AppColors.brand300,
      onPrimary: AppColors.brand900,
      surface: AppColors.surfaceAltDark,
      error: AppColors.errorDark,
    );

    return _base(colorScheme);
  }

  static ThemeData _base(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDefaultDark : AppColors.textDefault;
    final textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: textColor,
      displayColor: textColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.surfaceBaseDark : AppColors.scaffoldWash,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? AppColors.surfaceBaseDark : AppColors.scaffoldWash,
        foregroundColor:
            isDark ? AppColors.textDefaultDark : AppColors.textDefault,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textDefaultDark : AppColors.textDefault,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
        indicatorColor: (isDark ? AppColors.brand700 : AppColors.brand100)
            .withValues(alpha: 0.6),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontSize: 10,
            height: 1.1,
            letterSpacing: 0.1,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active
                ? (isDark ? AppColors.navActiveDark : AppColors.navActiveLight)
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary),
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.surfaceAltDark : AppColors.brand50,
        labelStyle: textTheme.labelMedium,
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.brand100,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
      ),
    );
  }
}
