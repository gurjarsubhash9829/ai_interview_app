import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,

    fontFamily: 'Roboto',

    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4F8BFF),
      secondary: Color(0xFF6FA8FF),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4F8BFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      hintStyle: const TextStyle(color: Colors.white70),
      border: InputBorder.none,
    ),
  );
}
