import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system for the Emergency Healthcare Access Platform.
///
/// Palette: deep medical blue (trust) + teal (care) on soft neutral
/// surfaces, with semantic colors for availability states.
class AppTheme {
  // ── Brand palette ──
  static const primary = Color(0xFF0D5BC6);
  static const primaryDark = Color(0xFF07408F);
  static const secondary = Color(0xFF00897B);
  static const accent = Color(0xFF00B8A9);

  // ── Surfaces ──
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6F8FB);
  static const surfaceBorder = Color(0xFFE4E9F0);

  // ── Text ──
  static const textPrimary = Color(0xFF16243A);
  static const textSecondary = Color(0xFF5A6B84);
  static const textTertiary = Color(0xFF8B99AF);

  // ── Semantic ──
  static const success = Color(0xFF1B873F);
  static const warning = Color(0xFFB35C00);
  static const danger = Color(0xFFC62828);

  // ── Motion ──
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const easeOut = Curves.easeOutCubic;

  // ── Shadows ──
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF16243A).withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardShadowHover => [
        BoxShadow(
          color: const Color(0xFF16243A).withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static ThemeData get lightTheme {
    // Inter has no Bengali glyphs — register Noto Sans Bengali as the
    // fallback so the taka sign (৳) and Bangla text render correctly.
    // Calling the constructor triggers google_fonts to load the font.
    final bengaliFallback = GoogleFonts.notoSansBengali().fontFamily!;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: danger,
      ),
      scaffoldBackgroundColor: background,
    );

    final interTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
          fontSize: 56, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1.5, color: textPrimary),
      displayMedium: GoogleFonts.inter(
          fontSize: 44, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -1, color: textPrimary),
      headlineLarge: GoogleFonts.inter(
          fontSize: 34, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.5, color: textPrimary),
      headlineMedium: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.5, color: textPrimary),
      headlineSmall: GoogleFonts.inter(
          fontSize: 23, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.25, color: textPrimary),
      titleLarge: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w600, color: textPrimary),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
      titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: GoogleFonts.inter(fontSize: 16, height: 1.55, color: textPrimary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, height: 1.5, color: textPrimary),
      bodySmall: GoogleFonts.inter(fontSize: 12.5, height: 1.45, color: textSecondary),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    );

    final textTheme = interTheme.apply(fontFamilyFallback: [bengaliFallback]);

    return base.copyWith(
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: surfaceBorder)),
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorder),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: textTertiary, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return Colors.white.withValues(alpha: 0.10);
            if (states.contains(WidgetState.pressed)) return Colors.white.withValues(alpha: 0.18);
            return null;
          }),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: surfaceBorder, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return primary.withValues(alpha: 0.05);
            return null;
          }),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: background,
        selectedColor: primary.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
        side: const BorderSide(color: surfaceBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      dividerTheme: const DividerThemeData(color: surfaceBorder, thickness: 1, space: 1),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w700, color: textPrimary),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: textPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        // FadeUpwards on every platform — a consistent, lightweight
        // full-page transition. (In-shell route changes use the custom
        // 220ms fade in routes.dart.) Avoids CupertinoPageTransitionsBuilder,
        // which isn't exported from material.dart on newer Flutter versions.
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
