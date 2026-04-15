import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF293c27);
  static const Color accentYellow = Color(0xFFffdb3a);
  static const Color institutionalPurple = Color(0xFF3F1274);
  static const Color foregroundColor = Colors.grey;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryGreen,
      secondary: accentYellow,
      tertiary: institutionalPurple,
    ),
    scaffoldBackgroundColor: Colors.grey.shade100,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
