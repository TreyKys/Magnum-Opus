import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Core palette — Blue-Black-White
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceVariant = Color(0xFF232323);
  static const Color border = Color(0xFF2A2A2A);

  // Blue accent system
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentBlueLight = Color(0xFF3B82F6);
  static const Color accentBlueDim = Color(0xFF1D4ED8);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF666666);

  // File type badge colours
  static const Color badgePdf = accentBlue;
  static const Color badgeEpub = Color(0xFF7C3AED);
  static const Color badgeDocx = Color(0xFF1E40AF);
  static const Color badgeXlsx = Color(0xFF16A34A);
  static const Color badgePptx = Color(0xFFEA580C);
  static const Color badgeCsv = Color(0xFF0D9488);
  static const Color badgeTxt = Color(0xFF6B7280);
  static const Color badgeAudio = Color(0xFFDB2777);
  static const Color badgeUrl = Color(0xFFD97706);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accentBlue,
      fontFamily: GoogleFonts.bricolageGrotesque().fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentBlueLight,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.bricolageGrotesque(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentBlue,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: accentBlue,
        unselectedLabelColor: Color(0xFF666666),
        indicatorColor: accentBlue,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accentBlue,
        inactiveTrackColor: Color(0xFF2A2A2A),
        thumbColor: Colors.white,
        overlayColor: Color(0x1F2563EB),
        valueIndicatorColor: accentBlue,
        valueIndicatorTextStyle: TextStyle(color: Colors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accentBlue : const Color(0xFF333333),
        ),
      ),
      dividerColor: border,
      textTheme: GoogleFonts.bricolageGrotesqueTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        titleLarge: GoogleFonts.bricolageGrotesque(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.bricolageGrotesque(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: GoogleFonts.bricolageGrotesque(color: textSecondary),
        bodySmall: GoogleFonts.bricolageGrotesque(color: textMuted),
        labelSmall: GoogleFonts.bricolageGrotesque(
          color: textMuted,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
