import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFF0A0A0A);
  static const Color accentCyan = Colors.cyanAccent;
  static const Color accentPurple = Colors.purpleAccent;
  static const Color surface = Color(0xFF1A1A1A);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: background,
      fontFamily: GoogleFonts.bricolageGrotesque().fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: background,
        secondary: accentCyan,
        surface: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
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
        backgroundColor: accentCyan,
        foregroundColor: Colors.black,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: accentCyan,
        unselectedLabelColor: Colors.white54,
        indicatorColor: accentCyan,
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
}
