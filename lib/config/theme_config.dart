import 'package:flutter/material.dart';

class ThemeConfig {
  // Brand colors
  static const Color primaryGreen = Color(0xFF0D3528);
  static const Color secondaryGreen = Color(0xFF4D6443);
  static const Color coffeeBrown = Color(0xFF4E2D18);
  static const Color mochaBrown = Color(0xFF8B6341);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFEEEEEE);
  static const Color midGray = Color(0xFFBFBFBF);

  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: white,
    primaryColor: primaryGreen,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: secondaryGreen,
      surface: white,
      onPrimary: white,
      onSecondary: white,
      onSurface: primaryGreen,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(
        color: Colors.grey[600],
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryGreen),
      ),
      // 👇 Apply focus color to hint when focused
      floatingLabelStyle: const TextStyle(
        color: primaryGreen,
      ),
    ),
    fontFamily: 'Roboto',
  );
}	
