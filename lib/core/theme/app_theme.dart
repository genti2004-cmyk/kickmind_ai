import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF06111F);
  static const Color surface = Color(0xFF0B1B2E);
  static const Color card = Color(0xFF102A45);
  static const Color blue = Color(0xFF00A8FF);
  static const Color blueDark = Color(0xFF006DFF);
  static const Color text = Color(0xFFF4F8FF);
  static const Color mutedText = Color(0xFF9FB4CC);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: blue,
        secondary: blueDark,
        surface: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: blue,
        unselectedItemColor: mutedText,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}