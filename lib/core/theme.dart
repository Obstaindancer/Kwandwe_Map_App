import 'package:flutter/material.dart';

class KwandweTheme {
  // Brand colours — earthy game reserve palette
  static const Color primary = Color(0xFF5C4A1E);      // dark earth brown
  static const Color secondary = Color(0xFF8B6914);    // golden savanna
  static const Color accent = Color(0xFFD4A843);       // warm amber
  static const Color background = Color(0xFF1A1A1A);   // dark background
  static const Color surface = Color(0xFF2C2C2C);      // card surface
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color danger = Color(0xFFD32F2F);       // red for critical alerts
  static const Color warning = Color(0xFFFF6F00);      // orange for high severity
  static const Color caution = Color(0xFFF9A825);      // yellow for medium severity

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onPrimary: onPrimary,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Color(0xFF1A1A1A),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 4,
      ),
    );
  }
}
