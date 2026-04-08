import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Colors
  static const Color lightPrimaryColor = Color(0xFF0084FF);
  static const Color lightSecondaryColor = Color(0xFF00C6FF);
  static const Color lightBackgroundColor = Color(0xFFFFFFFF);
  static const Color lightChatBubbleMe = Color(0xFF0084FF);
  static const Color lightChatBubbleOther = Color(0xFFE4E6EB);
  static const Color lightTextPrimary = Color(0xFF050505);
  static const Color lightTextSecondary = Color(0xFF65676B);
  static const Color lightErrorColor = Color(0xFFD32F2F);
  static const Color lightSurfaceColor = Color(0xFFF0F2F5);

  // Dark Theme Colors
  static const Color darkPrimaryColor = Color(0xFF0084FF);
  static const Color darkSecondaryColor = Color(0xFF00C6FF);
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkChatBubbleMe = Color(0xFF0084FF);
  static const Color darkChatBubbleOther = Color(0xFF2C2C2C);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);
  static const Color darkErrorColor = Color(0xFFCF6679);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);

  // Legacy getters for backward compatibility
  static Color get primaryColor => lightPrimaryColor;
  static Color get secondaryColor => lightSecondaryColor;
  static Color get backgroundColor => lightBackgroundColor;
  static Color get chatBubbleMe => lightChatBubbleMe;
  static Color get chatBubbleOther => lightChatBubbleOther;
  static Color get textPrimary => lightTextPrimary;
  static Color get textSecondary => lightTextSecondary;
  static Color get errorColor => lightErrorColor;

  // Helper getters for dynamic theming
  static Color getPrimaryColor(bool isDark) =>
      isDark ? darkPrimaryColor : lightPrimaryColor;
  static Color getBackgroundColor(bool isDark) =>
      isDark ? darkBackgroundColor : lightBackgroundColor;
  static Color getChatBubbleMe(bool isDark) =>
      isDark ? darkChatBubbleMe : lightChatBubbleMe;
  static Color getChatBubbleOther(bool isDark) =>
      isDark ? darkChatBubbleOther : lightChatBubbleOther;
  static Color getTextPrimary(bool isDark) =>
      isDark ? darkTextPrimary : lightTextPrimary;
  static Color getTextSecondary(bool isDark) =>
      isDark ? darkTextSecondary : lightTextSecondary;
  static Color getErrorColor(bool isDark) =>
      isDark ? darkErrorColor : lightErrorColor;
  static Color getSurfaceColor(bool isDark) =>
      isDark ? darkSurfaceColor : lightSurfaceColor;

  static ThemeData lightTheme = ThemeData(
    primaryColor: lightPrimaryColor,
    scaffoldBackgroundColor: lightBackgroundColor,
    colorScheme: const ColorScheme.light(
      primary: lightPrimaryColor,
      secondary: lightSecondaryColor,
      error: lightErrorColor,
      surface: lightSurfaceColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onError: Colors.white,
      onSurface: lightTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBackgroundColor,
      elevation: 0,
      iconTheme: IconThemeData(color: lightTextPrimary),
      titleTextStyle: TextStyle(
        color: lightTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightPrimaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: lightTextPrimary),
      bodyMedium: TextStyle(color: lightTextPrimary),
      bodySmall: TextStyle(color: lightTextSecondary),
      headlineLarge: TextStyle(color: lightTextPrimary),
      headlineMedium: TextStyle(color: lightTextPrimary),
      headlineSmall: TextStyle(color: lightTextPrimary),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    primaryColor: darkPrimaryColor,
    scaffoldBackgroundColor: darkBackgroundColor,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimaryColor,
      secondary: darkSecondaryColor,
      error: darkErrorColor,
      surface: darkSurfaceColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onError: Colors.white,
      onSurface: darkTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackgroundColor,
      elevation: 0,
      iconTheme: IconThemeData(color: darkTextPrimary),
      titleTextStyle: TextStyle(
        color: darkTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: darkTextPrimary),
      bodyMedium: TextStyle(color: darkTextPrimary),
      bodySmall: TextStyle(color: darkTextSecondary),
      headlineLarge: TextStyle(color: darkTextPrimary),
      headlineMedium: TextStyle(color: darkTextPrimary),
      headlineSmall: TextStyle(color: darkTextPrimary),
    ),
  );
}
