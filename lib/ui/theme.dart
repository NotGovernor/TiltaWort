import 'package:flutter/material.dart';

/// Tokens from planning/DESIGN.md (dark default).
abstract final class TiltColors {
  static const primary = Color(0xFFD6A84F);
  static const secondary = Color(0xFFC4C8C2);
  static const tertiary = Color(0xFF5A9BB8);
  static const neutral = Color(0xFF0B0D0C);
  static const onPrimary = Color(0xFF0B0D0C);
  static const onTertiary = Color(0xFF0B0D0C);
  static const surface = Color(0xFF161A16);
  static const ink = Color(0xFFF4F1E6);
  static const muted = Color(0xFF8B9388);
}

Color factorySwatch(String color) {
  switch (color) {
    case 'Red':
      return const Color(0xFFC4453A);
    case 'Green':
      return const Color(0xFF3B8F4F);
    case 'Black':
      return const Color(0xFF1A1C1A);
    case 'Purple':
      return const Color(0xFF7A4BA0);
    case 'Orange':
      return const Color(0xFFE07A2F);
    case 'Blue':
      return const Color(0xFF3A7BBF);
    case 'Yellow':
      return const Color(0xFFD6C43A);
    case 'Pink':
      return const Color(0xFFE26AA0);
    default:
      return TiltColors.secondary;
  }
}

ThemeData tiltDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: TiltColors.neutral,
    canvasColor: TiltColors.neutral,
    fontFamily: 'Sora',
    colorScheme: const ColorScheme.dark(
      primary: TiltColors.primary,
      onPrimary: TiltColors.onPrimary,
      secondary: TiltColors.secondary,
      tertiary: TiltColors.tertiary,
      onTertiary: TiltColors.onTertiary,
      surface: TiltColors.surface,
      onSurface: TiltColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: TiltColors.neutral,
      foregroundColor: TiltColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}

const oxaniumReadout = TextStyle(
  fontFamily: 'Oxanium',
  fontSize: 28,
  fontWeight: FontWeight.w700,
  height: 1.1,
  fontFeatures: [FontFeature.tabularFigures()],
);

const soraTitle = TextStyle(
  fontFamily: 'Sora',
  fontSize: 20,
  fontWeight: FontWeight.w600,
  height: 1.2,
  color: TiltColors.primary,
);

const soraBody = TextStyle(
  fontFamily: 'Sora',
  fontSize: 16,
  fontWeight: FontWeight.w400,
  height: 1.45,
  color: TiltColors.ink,
);

const soraMuted = TextStyle(
  fontFamily: 'Sora',
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.4,
  color: TiltColors.muted,
);

const soraLabel = TextStyle(
  fontFamily: 'Sora',
  fontSize: 12,
  fontWeight: FontWeight.w600,
  height: 1.2,
  letterSpacing: 0.48,
  color: TiltColors.secondary,
);
