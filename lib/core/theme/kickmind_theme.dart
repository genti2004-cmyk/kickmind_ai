import 'package:flutter/material.dart';

class KickMindTheme {
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color accent = Color(0xFF00A676);

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;

  static const Color textDark = Color(0xFF172033);
  static const Color textMuted = Color(0xFF6B7280);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: surface,
        background: background,
      ),
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background,
        foregroundColor: textDark,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(0.12),
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          final selected = states.contains(MaterialState.selected);
          return IconThemeData(color: selected ? primary : textMuted);
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: primary.withOpacity(0.12),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, color: textDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: const TextStyle(color: textDark, fontSize: 22, fontWeight: FontWeight.w900),
        titleMedium: const TextStyle(color: textDark, fontSize: 17, fontWeight: FontWeight.w900),
        bodyMedium: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w600),
        bodySmall: const TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  static Color scoreColor(int score) {
    if (score >= 82) return success;
    if (score >= 70) return warning;
    return danger;
  }

  static Color riskColor(String risk) {
    final value = risk.toLowerCase();
    if (value.contains('niedrig') || value.contains('low')) return success;
    if (value.contains('mittel') || value.contains('medium')) return warning;
    return danger;
  }
}
