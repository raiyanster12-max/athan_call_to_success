import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette._();

  static const Color backgroundTop = Color(0xFF121214);
  static const Color backgroundMid = Color(0xFF17171A);
  static const Color backgroundBottom = Color(0xFF1D1D21);

  static const Color surface = Color(0xFF1C1C1F);
  static const Color surfaceRaised = Color(0xFF232326);
  static const Color surfaceHighlight = Color(0xFF2B2B30);
  static const Color panel = Color(0xFF17171A);
  static const Color outline = Color(0xFF37373D);

  static const Color accent = Color(0xFF56D39A);
  static const Color accentSoft = Color(0xFF7CE2B4);
  static const Color secondary = Color(0xFF8FAFA0);
  static const Color danger = Color(0xFFE37D8F);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB2B2B8);
  static const Color textMuted = Color(0xFF8A8A92);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.45, 1.0],
    colors: [backgroundTop, backgroundMid, backgroundBottom],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accent, accentSoft],
  );
}
