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

class TiltPalette {
  const TiltPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.neutral,
    required this.onPrimary,
    required this.onTertiary,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.livePlate,
    required this.stalePlate,
    required this.liveInk,
    required this.staleInk,
    required this.mesh,
    required this.stalePill,
    required this.liveGold,
    required this.tempOnLive,
    required this.tempOnStale,
    required this.aluminum,
    required this.stampInk,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color neutral;
  final Color onPrimary;
  final Color onTertiary;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color livePlate;
  final Color stalePlate;
  final Color liveInk;
  final Color staleInk;
  final Color mesh;
  final Color stalePill;
  final Color liveGold;
  final Color tempOnLive;
  final Color tempOnStale;
  final Color aluminum;
  final Color stampInk;

  static const dark = TiltPalette(
    primary: TiltColors.primary,
    secondary: TiltColors.secondary,
    tertiary: TiltColors.tertiary,
    neutral: TiltColors.neutral,
    onPrimary: TiltColors.onPrimary,
    onTertiary: TiltColors.onTertiary,
    surface: TiltColors.surface,
    ink: TiltColors.ink,
    muted: TiltColors.muted,
    livePlate: Color(0xFFD2D5D8),
    stalePlate: Color(0xFF1A1D21),
    liveInk: Color(0xFF141612),
    staleInk: TiltColors.ink,
    mesh: Color(0x663A6A8A),
    stalePill: Color(0xFF4A6278),
    liveGold: Color(0xFF8A6418),
    tempOnLive: Color(0xFF2A3038),
    tempOnStale: Color(0xFFC4C8C2),
    aluminum: Color(0xFFD0D4D8),
    stampInk: Color(0xFF141612),
  );

  /// Sun on a greenhouse wall — not an invert of dark.
  static const light = TiltPalette(
    primary: Color(0xFF6B5010),
    secondary: Color(0xFF4A4E48),
    tertiary: Color(0xFF1E4A62),
    neutral: Color(0xFFF3EFE4),
    onPrimary: Color(0xFFF3EFE4),
    onTertiary: Color(0xFFF3EFE4),
    surface: Color(0xFFE8E2D4),
    ink: Color(0xFF121510),
    muted: Color(0xFF5A5E58),
    livePlate: Color(0xFFF6F1E4),
    stalePlate: Color(0xFFD4CDBE),
    liveInk: Color(0xFF121510),
    staleInk: Color(0xFF121510),
    mesh: Color(0x336B5010),
    stalePill: Color(0xFF8A8478),
    liveGold: Color(0xFF6B5010),
    tempOnLive: Color(0xFF1A1C18),
    tempOnStale: Color(0xFF1A1C18),
    aluminum: Color(0xFFE4DFD2),
    stampInk: Color(0xFF121510),
  );

  static TiltPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light ? light : dark;
  }
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

ThemeData tiltLightTheme() {
  const p = TiltPalette.light;
  return ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: p.neutral,
    canvasColor: p.neutral,
    fontFamily: 'Sora',
    colorScheme: ColorScheme.light(
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.secondary,
      tertiary: p.tertiary,
      onTertiary: p.onTertiary,
      surface: p.surface,
      onSurface: p.ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.neutral,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}

const oxaniumReadout = TextStyle(
  fontFamily: 'Oxanium',
  fontSize: 40,
  fontWeight: FontWeight.w700,
  height: 1.05,
  fontFeatures: [FontFeature.tabularFigures()],
);

const oxaniumHero = TextStyle(
  fontFamily: 'Oxanium',
  fontSize: 52,
  fontWeight: FontWeight.w700,
  height: 1.0,
  fontFeatures: [FontFeature.tabularFigures()],
);

const soraTitle = TextStyle(
  fontFamily: 'Sora',
  fontSize: 28,
  fontWeight: FontWeight.w600,
  height: 1.15,
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
