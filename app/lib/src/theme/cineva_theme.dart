import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class CinevaColors {
  static const bg = Color(0xFF0B0B0F);
  static const surface = Color(0xFF16161E);
  static const surfaceElevated = Color(0xFF1C1C24);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFFA1A1AA);
  static const mutedSoft = Color(0xFF71717A);
  static const accent = Color(0xFFFFD66B);
  static const accentDeep = Color(0xFFF0B429);
  static const border = Color(0x0FFFFFFF);
  static const chipBorder = Color(0x1FFFFFFF);
  static const navBg = Color(0xD9141414);
  static const onAccent = Color(0xFF111111);
}

ThemeData buildCinevaTheme() {
  // Be Vietnam Pro: designed for Vietnamese diacritics.
  // Outfit (and many Latin display fonts) misplace tone marks (e.g. ủ).
  // Use fontFamily on ThemeData so default TextStyles keep inherit:true.
  // Mixing GoogleFonts TextTheme (inherit:false) with const TextStyle
  // (inherit:true) breaks Material text animations.
  final bodyFont = GoogleFonts.beVietnamPro();
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: bodyFont.fontFamily,
    scaffoldBackgroundColor: CinevaColors.bg,
    colorScheme: const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: CinevaColors.accent,
      onPrimary: CinevaColors.onAccent,
      secondary: CinevaColors.accentDeep,
      onSecondary: CinevaColors.onAccent,
      surface: CinevaColors.surface,
      onSurface: CinevaColors.text,
      error: Color(0xFFF87171),
      onError: CinevaColors.onAccent,
    ),
  );

  final textTheme = base.textTheme.apply(
    bodyColor: CinevaColors.text,
    displayColor: CinevaColors.text,
    fontFamily: bodyFont.fontFamily,
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: CinevaColors.bg.withValues(alpha: 0.82),
      foregroundColor: CinevaColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: CinevaColors.text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      hintStyle: textTheme.bodyMedium?.copyWith(color: CinevaColors.mutedSoft),
      labelStyle: textTheme.bodyMedium?.copyWith(color: const Color(0xFFE4E4E7)),
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(
        color: CinevaColors.accent,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: CinevaColors.accent.withValues(alpha: 0.45),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFF87171)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFF87171)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CinevaColors.accent,
        foregroundColor: CinevaColors.onAccent,
        disabledBackgroundColor: CinevaColors.accent.withValues(alpha: 0.45),
        disabledForegroundColor: CinevaColors.onAccent.withValues(alpha: 0.7),
        elevation: 0,
        minimumSize: const Size.fromHeight(46),
        shape: const StadiumBorder(),
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      shape: const StadiumBorder(),
      labelStyle: textTheme.bodySmall?.copyWith(color: const Color(0xFFE4E4E7)),
      secondaryLabelStyle: textTheme.bodySmall?.copyWith(
        color: CinevaColors.accent,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
    ),
    dividerColor: Colors.white.withValues(alpha: 0.06),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CinevaColors.accent,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: CinevaColors.accent,
      unselectedItemColor: CinevaColors.muted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
