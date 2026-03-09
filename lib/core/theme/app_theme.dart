import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color electricPurple = Color(0xFFB026FF);
  static const Color darkBorder = Color(0xFF2A2A2A);

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE0E0E0);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: darkBackground,
        secondary: neonCyan,
        surface: darkSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: neonCyan,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: neonCyan,
        labelColor: neonCyan,
        unselectedLabelColor: Colors.white54,
      ),
      textTheme: GoogleFonts.bricolageGrotesqueTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        titleLarge: GoogleFonts.bricolageGrotesque(color: Colors.white, fontWeight: FontWeight.bold),
        bodyMedium: GoogleFonts.bricolageGrotesque(color: Colors.white70),
        bodySmall: GoogleFonts.bricolageGrotesque(color: Colors.white54),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightBackground,
        secondary: electricPurple,
        surface: lightSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: electricPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: electricPurple,
        labelColor: electricPurple,
        unselectedLabelColor: Colors.black54,
      ),
      textTheme: GoogleFonts.bricolageGrotesqueTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        titleLarge: GoogleFonts.bricolageGrotesque(color: Colors.black87, fontWeight: FontWeight.bold),
        bodyMedium: GoogleFonts.bricolageGrotesque(color: Colors.black54),
        bodySmall: GoogleFonts.bricolageGrotesque(color: Colors.black45),
      ),
    );
  }
}
