import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Magnum Opus design system — "Archival Instrument".
///
/// The palette is built on warm ink rather than neutral grey: every value
/// below carries a slight red/yellow bias so the app reads as printed matter
/// under lamplight rather than as a generic dark-mode shell. Text is
/// parchment, never pure white; the accent is muted brass, never the
/// default blue. Radii are tight — this is an instrument, not a toy.
class AppTheme {
  // ─── Ink (warm near-blacks) ────────────────────────────────────────────
  // Note the red/green/blue values step down, not across — that asymmetry
  // is what separates "warm ink" from "grey".
  static const Color background = Color(0xFF0C0A09);
  static const Color surface = Color(0xFF16130F);
  static const Color surfaceVariant = Color(0xFF1F1B16);
  static const Color surfaceRaised = Color(0xFF272119);
  static const Color border = Color(0xFF2E2720);
  static const Color borderStrong = Color(0xFF3D342A);

  // ─── Brass accent ──────────────────────────────────────────────────────
  static const Color accent = Color(0xFFC9973F);
  static const Color accentLight = Color(0xFFE5BE79);
  static const Color accentDim = Color(0xFF7A5A24);
  static const Color accentWash = Color(0x14C9973F); // 8% — tints and fills

  /// Ink for text and icons sitting ON a brass fill. Parchment-on-brass
  /// fails contrast badly, so anything with an `accent` background must
  /// use this rather than [textPrimary].
  static const Color onAccent = Color(0xFF1A1206);

  // Champagne, reserved exclusively for the Lifetime tier so it still
  // reads as "above" the brass used everywhere else.
  static const Color champagne = Color(0xFFE8D9A0);

  // ─── Type colours (parchment, not white) ───────────────────────────────
  static const Color textPrimary = Color(0xFFF2EDE3);
  static const Color textSecondary = Color(0xFFA8A096);
  static const Color textMuted = Color(0xFF6E665C);

  // ─── Semantic ──────────────────────────────────────────────────────────
  static const Color danger = Color(0xFFB5533C);
  static const Color success = Color(0xFF6B8F5E);

  // ─── File-type marks ───────────────────────────────────────────────────
  // Muted and earthy so the library reads as a considered set rather than
  // a default rainbow. Each is legible on `surface` at small sizes.
  static const Color badgePdf = Color(0xFFB5533C); // rubrication red
  static const Color badgeEpub = Color(0xFF7E6394); // plum
  static const Color badgeDocx = Color(0xFF5B7A9E); // slate blue
  static const Color badgeXlsx = Color(0xFF6B8F5E); // sage
  static const Color badgePptx = Color(0xFFC1703F); // terracotta
  static const Color badgeCsv = Color(0xFF4F8A80); // verdigris
  static const Color badgeTxt = Color(0xFF8A8178); // warm grey
  static const Color badgeAudio = Color(0xFFB0587A); // rose
  static const Color badgeUrl = Color(0xFFB8913C); // ochre

  // ─── Shape ─────────────────────────────────────────────────────────────
  static const double radiusCard = 8;
  static const double radiusControl = 6;
  static const double radiusLarge = 10;
  static const double radiusSheet = 20;

  // ─── Type ──────────────────────────────────────────────────────────────
  // Fraunces (serif) carries brand and headline moments; Bricolage
  // Grotesque carries UI and body. The pairing is deliberately editorial.
  // To swap the display face, change only this method.
  static TextStyle display({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textPrimary,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.fraunces(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle ui({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textPrimary,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Wide-tracked caps used for section headers ("RECENT DOCUMENTS").
  /// The heavy tracking is a signature of the system — keep it consistent.
  static TextStyle eyebrow({Color color = textMuted}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.8,
      );

  // ─── Reusable decoration ───────────────────────────────────────────────

  /// Standard panel: warm surface, hairline border, tight radius.
  static BoxDecoration panel({Color? color, double? radius, Color? borderColor}) =>
      BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(radius ?? radiusCard),
        border: Border.all(color: borderColor ?? border),
      );

  /// Panel with a brass spine on the leading edge — used to mark AI output
  /// and source citations. This is the app's most recognisable motif.
  static BoxDecoration spinePanel({Color spine = accent, Color? color}) =>
      BoxDecoration(
        color: color ?? surface,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(radiusCard),
          bottomRight: Radius.circular(radiusCard),
        ),
        border: Border(left: BorderSide(color: spine, width: 2)),
      );

  static ThemeData get darkTheme {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      fontFamily: GoogleFonts.bricolageGrotesque().fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentLight,
        surface: surface,
        error: danger,
        onPrimary: onAccent,
        onSecondary: onAccent,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.fraunces(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: GoogleFonts.fraunces(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.bricolageGrotesque(
          color: textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle: GoogleFonts.bricolageGrotesque(
          color: textPrimary,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: textMuted,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: border,
        thumbColor: accentLight,
        overlayColor: accentWash,
        valueIndicatorColor: accent,
        valueIndicatorTextStyle: TextStyle(color: onAccent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? onAccent
              : textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accent : surfaceVariant,
        ),
        trackOutlineColor: WidgetStateProperty.all(border),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        hintStyle: GoogleFonts.bricolageGrotesque(color: textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: accent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentLight,
          textStyle: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: border,
      ),
      dividerColor: border,
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.bricolageGrotesqueTextTheme(base.textTheme).copyWith(
        // Headlines take the serif; everything else stays grotesque.
        displayLarge: GoogleFonts.fraunces(
            color: textPrimary, fontWeight: FontWeight.w600),
        displayMedium: GoogleFonts.fraunces(
            color: textPrimary, fontWeight: FontWeight.w600),
        displaySmall: GoogleFonts.fraunces(
            color: textPrimary, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.fraunces(
            color: textPrimary, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.fraunces(
            color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.fraunces(
            color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.bricolageGrotesque(
            color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.bricolageGrotesque(color: textPrimary),
        bodyMedium: GoogleFonts.bricolageGrotesque(color: textSecondary),
        bodySmall: GoogleFonts.bricolageGrotesque(color: textMuted),
        labelSmall: GoogleFonts.bricolageGrotesque(
          color: textMuted,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
