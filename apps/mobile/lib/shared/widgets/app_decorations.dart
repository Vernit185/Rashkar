import 'package:flutter/material.dart';
import 'package:cropnet_mobile/shared/theme/rashkar_tokens.dart';

export 'package:cropnet_mobile/shared/theme/rashkar_tokens.dart';
export 'package:cropnet_mobile/shared/theme/rashkar_components.dart';

/// Border radius tokens for RASHKAR / CropNet AI widgets.
class AppBorderRadius {
  const AppBorderRadius._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double cardRadius = RashkarRadii.card; // 18px
  static const double heroCardRadius = RashkarRadii.heroCard; // 22px
  static const double buttonRadius = RashkarRadii.button; // 16px
  static const double full = 999.0;

  static const BorderRadius allXS = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius allSM = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius allMD = BorderRadius.all(Radius.circular(md));
  static const BorderRadius allLG = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius allXL = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(full));

  // RASHKAR exact tokens:
  static const BorderRadius card = allMD;
  static const BorderRadius rashkarCard = BorderRadius.all(Radius.circular(cardRadius)); // 18px
  static const BorderRadius heroCard = BorderRadius.all(Radius.circular(heroCardRadius)); // 22px
  static const BorderRadius button = BorderRadius.all(Radius.circular(buttonRadius)); // 16px
  static const BorderRadius chip = pill;
}

/// Elevation and BoxShadow tokens.
/// RASHKAR Rule 4: Cards have 1px line border, no shadow.
/// Shadow only on floating action button and toasts: 0 6px 18px rgba(36,51,41,0.25).
class AppShadows {
  const AppShadows._();

  // RASHKAR spec: No shadows on cards in default views
  static const List<BoxShadow> subtle = [];
  static const List<BoxShadow> card = [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))];
  static const List<BoxShadow> elevated = [];

  // Shadow allowed only on FAB and toasts
  static const List<BoxShadow> floating = RashkarShadows.fabAndToast;
  static const List<BoxShadow> fabAndToast = RashkarShadows.fabAndToast;
}

/// RASHKAR Design Language Agricultural Design Tokens & Decoration Factories.
class AppDecorations {
  const AppDecorations._();

  // RASHKAR Palette Tokens
  static const Color primaryGreen = RashkarColors.forest;       // #214E34
  static const Color primaryDark = RashkarColors.forestDark;     // #173A26
  static const Color leafGreen = RashkarColors.leaf;             // #79A85A
  static const Color leafSoft = RashkarColors.leafSoft;          // #E8F0DF
  static const Color surfaceMuted = RashkarColors.cream;         // #F7F7F0
  static const Color sand = RashkarColors.sand;                  // #EFEEE3
  static const Color borderLight = RashkarColors.line;           // #E6E6DC
  static const Color ink = RashkarColors.ink;                    // #243329
  static const Color muted = RashkarColors.muted;                // #6B736B
  static const Color accentOrange = RashkarColors.orange;        // #E07A3A
  static const Color amber = RashkarColors.amber;                // #EBAF42
  static const Color risk = RashkarColors.risk;                  // #D95746

  /// Standard RASHKAR card decoration: white, 1px line border, 18px radius, no shadow.
  static BoxDecoration card({
    Color? backgroundColor,
    Border? border,
    BorderRadius? borderRadius,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? Colors.white,
      borderRadius: borderRadius ?? AppBorderRadius.card,
      border: border ?? Border.all(color: borderLight, width: 1.0),
      boxShadow: shadows ?? AppShadows.card,
    );
  }

  /// Elevated card decoration (clean outline per RASHKAR spec).
  static BoxDecoration elevatedCard({
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? Colors.white,
      borderRadius: borderRadius ?? AppBorderRadius.card,
      border: Border.all(color: borderLight, width: 1.0),
      boxShadow: AppShadows.card,
    );
  }

  /// Outlined card decoration.
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

  /// Agricultural accent card with a 4px colored accent bar.
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
      border: Border(
        left: BorderSide(color: accentColor, width: accentWidth),
        top: const BorderSide(color: borderLight, width: 1.0),
        right: const BorderSide(color: borderLight, width: 1.0),
        bottom: const BorderSide(color: borderLight, width: 1.0),
      ),
    );
  }
}
