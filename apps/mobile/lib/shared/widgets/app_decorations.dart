import 'package:flutter/material.dart';

/// Border radius tokens for CropNet AI widgets.
class AppBorderRadius {
  const AppBorderRadius._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;

  static const BorderRadius allXS = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius allSM = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius allMD = BorderRadius.all(Radius.circular(md));
  static const BorderRadius allLG = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius allXL = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(full));

  static const BorderRadius card = allMD;
  static const BorderRadius button = allSM;
  static const BorderRadius chip = pill;
}

/// Elevation and BoxShadow tokens.
class AppShadows {
  const AppShadows._();

  /// Subtle shadow for resting cards and clean surfaces.
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0F000000), // ~6% opacity black
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  /// Standard card shadow.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14000000), // ~8% opacity black
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: -2,
    ),
  ];

  /// Elevated shadow for dialogs, modals, and hovering cards.
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1F000000), // ~12% opacity black
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -4,
    ),
  ];

  /// Floating action or overlay shadow.
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x2E000000), // ~18% opacity black
      offset: Offset(0, 12),
      blurRadius: 28,
      spreadRadius: -4,
    ),
  ];
}

/// CropNet AI agricultural design tokens and decoration factories.
class AppDecorations {
  const AppDecorations._();

  // Agricultural Brand Palette Colors
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color accentOrange = Color(0xFFE65100);
  static const Color soilBrown = Color(0xFF5D4037);
  static const Color surfaceMuted = Color(0xFFF9FBF9);
  static const Color borderLight = Color(0xFFE0E0E0);

  /// Standard card decoration.
  static BoxDecoration card({
    Color? backgroundColor,
    Border? border,
    BorderRadius? borderRadius,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? Colors.white,
      borderRadius: borderRadius ?? AppBorderRadius.card,
      border: border ?? Border.all(color: borderLight, width: 1),
      boxShadow: shadows ?? AppShadows.subtle,
    );
  }

  /// Elevated card decoration with distinct depth.
  static BoxDecoration elevatedCard({
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? Colors.white,
      borderRadius: borderRadius ?? AppBorderRadius.card,
      boxShadow: AppShadows.card,
    );
  }

  /// Outlined card decoration without shadow.
  static BoxDecoration outlinedCard({
    Color? backgroundColor,
    Color? borderColor,
    double borderWidth = 1.0,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? Colors.white,
      borderRadius: borderRadius ?? AppBorderRadius.card,
      border: Border.all(
        color: borderColor ?? borderLight,
        width: borderWidth,
      ),
    );
  }

  /// Agricultural accent card with a tinted left border indicator.
  static BoxDecoration accentCard({
    Color? backgroundColor,
    Color accentColor = leafGreen,
    double accentWidth = 4.0,
    BorderRadius? borderRadius,
  }) {
    final radius = borderRadius ?? AppBorderRadius.card;
    return BoxDecoration(
      color: backgroundColor ?? Colors.white,
      borderRadius: radius,
      boxShadow: AppShadows.subtle,
      border: Border(
        left: BorderSide(color: accentColor, width: accentWidth),
        top: const BorderSide(color: borderLight, width: 1),
        right: const BorderSide(color: borderLight, width: 1),
        bottom: const BorderSide(color: borderLight, width: 1),
      ),
    );
  }
}
