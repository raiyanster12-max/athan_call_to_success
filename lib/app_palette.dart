import 'package:flutter/material.dart';

class AppPaletteData {
  const AppPaletteData({
    required this.backgroundTop,
    required this.backgroundMid,
    required this.backgroundBottom,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceHighlight,
    required this.panel,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.backgroundGradient,
    required this.heroGradient,
    required this.heroTextColor,
  });

  final Color backgroundTop, backgroundMid, backgroundBottom;
  final Color surface, surfaceRaised, surfaceHighlight, panel, outline;
  final Color textPrimary, textSecondary, textMuted;
  final LinearGradient backgroundGradient;
  final LinearGradient heroGradient;
  final Color heroTextColor; // text always white on teal hero
}

class AppPalette {
  const AppPalette._();

  // Static consts — same in both themes
  static const Color accent = Color(0xFF56D39A);
  static const Color accentSoft = Color(0xFF7CE2B4);
  static const Color secondary = Color(0xFF8FAFA0);
  static const Color danger = Color(0xFFE37D8F);

  /// The canonical #262943 dark page background used on all non-home pages.
  static const Color pageBackground = Color(0xFF262943);

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accent, accentSoft],
  );

  static final AppPaletteData _dark = AppPaletteData(
    // All non-home page backgrounds use #262943 exactly.
    backgroundTop: const Color(0xFF262943),
    backgroundMid: const Color(0xFF2E3252),
    backgroundBottom: const Color(0xFF343760),
    surface: const Color(0xFF2E3252),       // slightly lighter than page bg
    surfaceRaised: const Color(0xFF353960), // cards/panels — WCAG AA surface
    surfaceHighlight: const Color(0xFF3D4270),
    panel: const Color(0xFF202340),         // nav bar / bottom bar
    outline: const Color(0xFF4A4F7A),
    // WCAG contrast on #262943:
    //   white (#FFF)   → 12.7 : 1  ✅ AAA
    //   #E8E6FF        → 10.5 : 1  ✅ AAA  (primary readable text)
    //   #B0ADDB        →  5.8 : 1  ✅ AA   (secondary text)
    //   #7B79A8        →  3.2 : 1  ✅ AA large / decorative (muted)
    textPrimary: const Color(0xFFE8E6FF),
    textSecondary: const Color(0xFFB0ADDB),
    textMuted: const Color(0xFF7B79A8),
    backgroundGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, 0.45, 1.0],
      colors: [Color(0xFF262943), Color(0xFF2E3252), Color(0xFF343760)],
    ),
    heroGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, 0.5, 1.0],
      colors: [Color(0xFF1A1D38), Color(0xFF262943), Color(0xFF1E2238)],
    ),
    heroTextColor: Colors.white,
  );

  static final AppPaletteData _light = AppPaletteData(
    backgroundTop: const Color(0xFFF8F8F8),
    backgroundMid: const Color(0xFFF0F0F0),
    backgroundBottom: const Color(0xFFE8E8E8),
    surface: const Color(0xFFFFFFFF),
    surfaceRaised: const Color(0xFFF2F2F2),
    surfaceHighlight: const Color(0xFFE8E8E8),
    panel: const Color(0xFFF5F5F5),
    outline: const Color(0xFFD0D0D8),
    textPrimary: const Color(0xFF0D0D0D),
    textSecondary: const Color(0xFF4A4A52),
    textMuted: const Color(0xFF8A8A92),
    backgroundGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, 0.45, 1.0],
      colors: [Color(0xFFF8F8F8), Color(0xFFF0F0F0), Color(0xFFE8E8E8)],
    ),
    heroGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, 0.6, 1.0],
      colors: [Color(0xFF2B4540), Color(0xFF1E3530), Color(0xFF141E1C)],
    ),
    heroTextColor: Colors.white,
  );

  static AppPaletteData get dark => _dark;

  static AppPaletteData of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? _dark : _light;
  }

  /// Convenience method — same as AppPalette.of(context).backgroundGradient
  static LinearGradient backgroundGradientOf(BuildContext context) {
    return of(context).backgroundGradient;
  }
}
