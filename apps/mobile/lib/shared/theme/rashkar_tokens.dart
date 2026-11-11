import 'package:flutter/material.dart';

/// RASHKAR Design Language - Core Design Tokens
/// Exact hex codes and design rules as per RASHKAR Design System specification.
abstract final class RashkarColors {
  // Brand Colors
  static const Color forest = Color(0xFF287D49);       // Primary brand, primary buttons, headers, active nav
  static const Color forestDark = Color(0xFF205C38);   // Primary hover / pressed
  static const Color leaf = Color(0xFF39764E);         // Secondary brand, focus ring
  static const Color leafSoft = Color(0xFFE8F0EB);     // Icon tiles, selected backgrounds, success tint

  // Neutral Surfaces & Borders
  static const Color cream = Color(0xFFF8FAF8);        // App background
  static const Color sand = Color(0xFFEDF3EE);         // Neutral tiles, segmented-control track, skeleton base
  static const Color white = Color(0xFFFFFFFF);        // Cards, inputs
  static const Color line = Color(0xFFDCE5DE);         // All borders and dividers (1px)

  // Typography Colors
  static const Color ink = Color(0xFF20252C);          // Primary text
  static const Color muted = Color(0xFF58685F);        // Secondary text

  // Warning & Accents
  static const Color amber = Color(0xFFEBAF42);        // Warning, accent buttons, "Preliminary" tags
  static const Color amberSoft = Color(0xFFFBF0D9);    // Warning backgrounds
  static const Color amberText = Color(0xFF6B4C0E);    // Text on amberSoft

  // High Severity
  static const Color orange = Color(0xFFE07A3A);       // High severity
  static const Color orangeSoft = Color(0xFFFBE7DA);   // High tint
  static const Color orangeText = Color(0xFF8A3F12);   // Text on orangeSoft

  // Critical / Errors
  static const Color risk = Color(0xFFD95746);         // Critical/extreme, errors, unread dots
  static const Color riskSoft = Color(0xFFF9E2DE);     // Error backgrounds
  static const Color riskText = Color(0xFF8E2A1D);     // Text on riskSoft

  // Status In-Progress
  static const Color infoSoft = Color(0xFFE7EEF5);     // "In progress" pills
  static const Color infoText = Color(0xFF2D4F6E);     // Text on infoSoft

  // Disabled State
  static const Color disabled = Color(0xFFB8BFB5);
}

/// 4-Level Status Scale Mapping
enum RashkarStatusLevel {
  low(1, 'LOW', Color(0xFF4E8A3E), Color(0xFFE8F0EB), Color(0xFF2F5E25), Icons.shield_outlined),
  moderate(2, 'MODERATE', Color(0xFFEBAF42), Color(0xFFFBF0D9), Color(0xFF7A5710), Icons.wb_sunny_outlined),
  high(3, 'HIGH', Color(0xFFE07A3A), Color(0xFFFBE7DA), Color(0xFF8A3F12), Icons.warning_amber_rounded),
  extreme(4, 'EXTREME', Color(0xFFD95746), Color(0xFFF9E2DE), Color(0xFF8E2A1D), Icons.local_fire_department_outlined);

  final int level;
  final String label;
  final Color color;
  final Color softColor;
  final Color textColor;
  final IconData icon;

  const RashkarStatusLevel(
    this.level,
    this.label,
    this.color,
    this.softColor,
    this.textColor,
    this.icon,
  );

  static RashkarStatusLevel fromString(String? val) {
    if (val == null) return RashkarStatusLevel.low;
    final lower = val.toLowerCase();
    if (lower.contains('extreme') || lower.contains('critical') || lower.contains('severe') || lower.contains('hazard')) {
      return RashkarStatusLevel.extreme;
    }
    if (lower.contains('high') || lower.contains('warn')) {
      return RashkarStatusLevel.high;
    }
    if (lower.contains('mod') || lower.contains('med') || lower.contains('fair')) {
      return RashkarStatusLevel.moderate;
    }
    return RashkarStatusLevel.low;
  }
}

/// Exact Typography Scale & Styles
abstract final class RashkarTypography {
  static const String primaryFont = 'Inter';
  static const List<String> fontFallbacks = ['Noto Sans Devanagari', 'sans-serif'];

  static const TextStyle heroMetric = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: fontFallbacks,
    fontSize: 42.0,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    height: 1.1,
    color: RashkarColors.ink,
  );

  static const TextStyle pageTitle = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: fontFallbacks,
    fontSize: 26.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
    color: RashkarColors.ink,
  );

  static const TextStyle sheetTitle = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: fontFallbacks,
    fontSize: 20.0,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: RashkarColors.ink,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: fontFallbacks,
    fontSize: 19.0,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: RashkarColors.ink,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: fontFallbacks,
    fontSize: 17.0,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: RashkarColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: fontFallbacks,
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: RashkarColors.ink,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: fontFallbacks,
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: RashkarColors.ink,
  );

  static const TextStyle meta = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: fontFallbacks,
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: RashkarColors.muted,
  );

  static const TextStyle pill = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: fontFallbacks,
    fontSize: 12.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.05,
    color: RashkarColors.ink,
  );

  static const TextStyle wordmark = TextStyle(
    fontFamily: primaryFont,
    fontFamilyFallback: fontFallbacks,
    fontSize: 16.0,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.24, // 0.14em
    color: RashkarColors.white,
  );
}

/// Exact Shape, Radii & Spacing Tokens
abstract final class RashkarRadii {
  static const double heroCard = 18.0;
  static const double card = 14.0;
  static const double button = 12.0;
  static const double input = 12.0;
  static const double selectableTile = 16.0;
  static const double iconTile = 14.0;
  static const double bottomSheetTop = 26.0;
  static const double pill = 999.0;

  static const BorderRadius heroCardBorderRadius = BorderRadius.all(Radius.circular(heroCard));
  static const BorderRadius cardBorderRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonBorderRadius = BorderRadius.all(Radius.circular(button));
  static const BorderRadius inputBorderRadius = BorderRadius.all(Radius.circular(input));
  static const BorderRadius iconTileBorderRadius = BorderRadius.all(Radius.circular(iconTile));
  static const BorderRadius bottomSheetBorderRadius = BorderRadius.vertical(top: Radius.circular(bottomSheetTop));
  static const BorderRadius pillBorderRadius = BorderRadius.all(Radius.circular(pill));
}

abstract final class RashkarSpacing {
  static const double screenPadding = 16.0;
  static const double pageHeaderPadding = 20.0;
  static const double cardPadding = 16.0;
  static const double betweenCards = 12.0;
  static const double aboveSectionTitle = 28.0;
  static const double belowSectionTitle = 12.0;
  static const double minTouchTarget = 44.0;
  static const double primaryButtonHeight = 56.0;
}

abstract final class RashkarShadows {
  // Only the floating action button and toasts use shadow: 0 6px 18px rgba(36,51,41,0.25)
  static const List<BoxShadow> fabAndToast = [
    BoxShadow(
      color: Color(0x40243329), // rgba(36, 51, 41, 0.25)
      offset: Offset(0, 6),
      blurRadius: 18,
      spreadRadius: 0,
    ),
  ];
}
