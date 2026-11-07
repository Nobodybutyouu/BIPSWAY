import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized visual tokens for Bipsway.
///
/// TODO: Verify these approximations against the approved Figma prototype.
class AppTheme {
  AppTheme._();

  // TODO: Verify colors against Figma.
  static const navy = Color(0xFF0B2E73);
  static const gold = Color(0xFFFFB800);
  static const surface = Colors.white;
  static const darkSurface = Color(0xFF111827);
  static const outline = Color(0xFFD1D5DB);
  static const bodyText = Color(0xFF1F2937);
  static const mutedText = Color(0xFF6B7280);

  static ThemeData get light {
    final base = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: gold,
        surface: surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: surface,
      useMaterial3: true,
    );
    return _build(base);
  }

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: gold,
        surface: darkSurface,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: darkSurface,
      useMaterial3: true,
    );
    return _build(base);
  }

  static ThemeData _build(ThemeData base) {
    // Tests and offline launches use the system fallback until bundled fonts
    // are added; production can fetch the selected Google Fonts normally.
    GoogleFonts.config.allowRuntimeFetching = false;
    final body = GoogleFonts.interTextTheme(base.textTheme);
    final text = body.copyWith(
      displayLarge: GoogleFonts.poppins(
        textStyle: body.displayLarge,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.poppins(
        textStyle: body.displayMedium,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.poppins(
        textStyle: body.headlineLarge,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.poppins(
        textStyle: body.headlineMedium,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.poppins(
        textStyle: body.titleLarge,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.poppins(
        textStyle: body.titleMedium,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: bodyText),
      bodyMedium: body.bodyMedium?.copyWith(color: bodyText),
    );

    return base.copyWith(
      textTheme: text,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.brightness == Brightness.light
            ? surface
            : darkSurface.withValues(alpha: 0.8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        prefixIconColor: mutedText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: navy, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          side: const BorderSide(color: navy),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
