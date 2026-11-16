import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF0B0F17);     // oklch(0.155 0.012 256)
  static const Color card = Color(0xFF151C28);           // oklch(0.205 0.014 256)
  static const Color secondary = Color(0xFF1E2736);      // oklch(0.255 0.016 256)
  static const Color foreground = Color(0xFFF1F5F9);     // oklch(0.96 0.005 256)
  static const Color primary = Color(0xFFE2E8F0);        // oklch(0.92 0.012 256)
  static const Color primaryFg = Color(0xFF0F172A);      // oklch(0.20 0.014 256)
  static const Color mutedFg = Color(0xFF94A3B8);        // oklch(0.72 0.018 256)
  static const Color steel1 = Color(0xFFABB8C9);         // oklch(0.78 0.03 256)
  static const Color steel2 = Color(0xFF728399);         // oklch(0.60 0.04 256)
  static const Color border = Color(0x18FFFFFF);         // oklch(1 0 0 / 9%)
  static const Color emerald = Color(0xFF10B981);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: card,
        primary: primary,
        onPrimary: primaryFg,
        secondary: secondary,
        onSecondary: foreground,
        onSurface: foreground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xCC0B0F17),
        foregroundColor: foreground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0E141F),
        labelStyle: const TextStyle(color: mutedFg, fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: steel1, width: 1.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: primaryFg,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}