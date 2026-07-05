import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color accent = Color(0xFFC9A962);
  static const Color accentDark = Color(0xFFB8924F);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color canceled = Color(0xFF8A8A8A);
  static const Color slotError = Color(0xFFCF6679);

  static const Color slotAvailableBackground = surface;
  static const Color slotAvailableBorder = accent;
  static const Color slotAvailableForeground = textPrimary;

  static const Color slotBlockedBackground = Color(0x33CF6679);
  static const Color slotBlockedBorder = slotError;
  static const Color slotBlockedForeground = slotError;

  static const Color slotBookedBackground = Color(0x338A8A8A);
  static const Color slotBookedBorder = canceled;
  static const Color slotBookedForeground = canceled;

  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.black,
      secondary: accentDark,
      surface: surface,
      onSurface: textPrimary,
      error: const Color(0xFFCF6679),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.black,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: 0.3),
        labelStyle: const TextStyle(color: textPrimary),
        side: const BorderSide(color: accent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
