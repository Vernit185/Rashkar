import 'package:flutter/material.dart';

/// Semantic severity styling quadruple matching the Rashkar Figma Make
/// 4-band risk system (`LOW`, `MODERATE`, `HIGH`, `EXTREME`).
class RashkarSeverityStyle {
  final Color foreground;
  final Color bar;
  final Color background;
  final Color border;
  final String label;
  final IconData icon;
  final int levelIndex;

  const RashkarSeverityStyle({
    required this.foreground,
    required this.bar,
    required this.background,
    required this.border,
    required this.label,
    required this.icon,
    required this.levelIndex,
  });
}

/// Accessible Agriculture Public Service & Farmer-First Color System
/// inspired by AgriNova's understated mint-green, pale sage, and white palette
/// while adhering to WCAG 2.2 AA/AAA outdoor-sunlight contrast guidelines.
class RashkarColors {
  const RashkarColors._();

  // AgriNova-Inspired Clean Canvas & Warm Soft Mint Surfaces
  static const Color canvas = Color(0xFFFAF9F3); // Warm cream canvas (#FAF9F3)
  static const Color deskBg = Color(0xFFF6F7F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFFAF9F3);
  static const Color softMint = Color(0xFFE8F0E8);
  static const Color paleSage = Color(0xFFE2E8E0);
  static const Color border = Color(0xFFE2E8E0);
  static const Color borderStrong = Color(0xFFCCD5CA);

  // Warm Human Agritech Accents (Natural Palette)
  static const Color warmCream = Color(0xFFFAF9F3);
  static const Color softSage = Color(0xFFE5EFE5);
  static const Color lightMint = Color(0xFFDCEBDD);
  static const Color warmYellow = Color(0xFFF5E9BE);
  static const Color warmYellowBg = Color(0xFFFFFDF5);
  static const Color mutedPeach = Color(0xFFF5E1D3);
  static const Color mutedPeachBg = Color(0xFFFDF7F4);
  static const Color softBlue = Color(0xFFE1EFF2);
  static const Color softBlueBg = Color(0xFFF5FBFC);

  // AgriNova Dark Text Typography (High-Contrast, Warm Charcoal)
  static const Color ink = Color(0xFF202924);
  static const Color mutedInk = Color(0xFF68766D);
  static const Color subtleInk = Color(0xFF8A978F);

  // Main Agricultural Green (Primary Brand, Buttons & Active Accents)
  static const Color forest = Color(0xFF27804C);
  static const Color forestDark = Color(0xFF1D5D3A);
  static const Color forestTint = Color(0xFF27804C);
  static const Color forestTextMuted = Color(0xFFE8F0E8);
  static const Color agGreen = Color(0xFF27804C);

  // Subtle Natural Mint Highlight Tints
  static const Color mintBg = Color(0xFFDDEBDF);
  static const Color mintTrack = Color(0xFFE8F0E8);
  static const Color mintBorder = Color(0xFFCCD5CA);

  // Restrained Earth Amber Secondary Accent (Muted Warnings & Heat Risks Only)
  static const Color marigold = Color(0xFFD97706);
  static const Color marigoldTint = Color(0xFFFFF8E7);
  static const Color marigoldBorder = Color(0xFFE5C07B);
  static const Color marigoldInk = Color(0xFF7A3C1C);

  // Calm Institutional Steel Info Callout
  static const Color skyBg = Color(0xFFEFF5F4);
  static const Color skyFg = Color(0xFF1B5E4B);
  static const Color skyBorder = Color(0xFFC7DFD9);

  // Accessible 4-Band Risk Severity Scale (Green -> Amber -> Orange -> Crimson)
  static const Color lowFg = Color(0xFF1B5E34);
  static const Color lowBar = Color(0xFF287D49);
  static const Color lowBg = Color(0xFFE8F0EB);
  static const Color lowBorder = Color(0xFFDCE9DF);

  static const Color moderateFg = Color(0xFF7A3C1C);
  static const Color moderateBar = Color(0xFFD97706);
  static const Color moderateBg = Color(0xFFFFF8E7);
  static const Color moderateBorder = Color(0xFFE5C07B);

  static const Color highFg = Color(0xFF8A3800);
  static const Color highBar = Color(0xFFD95F18);
  static const Color highBg = Color(0xFFFEF0E6);
  static const Color highBorder = Color(0xFFF3BA95);

  static const Color extremeFg = Color(0xFF721C24);
  static const Color extremeBar = Color(0xFFCA3535);
  static const Color extremeBg = Color(0xFFFCF5F5);
  static const Color extremeBorder = Color(0xFFE59A9A);

  // Satellite vegetation ramp (Restrained greens to terracotta/red)
  static const List<Color> vegetationRamp = [
    Color(0xFF1B5E34),
    Color(0xFF287D49),
    Color(0xFF5E9E75),
    Color(0xFFD97706),
    Color(0xFFD95F18),
    Color(0xFFCA3535),
  ];

  static const List<RashkarSeverityStyle> severityBands = [
    RashkarSeverityStyle(
      foreground: lowFg,
      bar: lowBar,
      background: lowBg,
      border: lowBorder,
      label: 'LOW',
      icon: Icons.verified_user_outlined,
      levelIndex: 1,
    ),
    RashkarSeverityStyle(
      foreground: moderateFg,
      bar: moderateBar,
      background: moderateBg,
      border: moderateBorder,
      label: 'MODERATE',
      icon: Icons.wb_sunny_outlined,
      levelIndex: 2,
    ),
    RashkarSeverityStyle(
      foreground: highFg,
      bar: highBar,
      background: highBg,
      border: highBorder,
      label: 'HIGH',
      icon: Icons.warning_amber_rounded,
      levelIndex: 3,
    ),
    RashkarSeverityStyle(
      foreground: extremeFg,
      bar: extremeBar,
      background: extremeBg,
      border: extremeBorder,
      label: 'EXTREME',
      icon: Icons.local_fire_department_outlined,
      levelIndex: 4,
    ),
  ];

  /// Maps any CropNet or Rashkar risk / status string cleanly to a 4-band style.
  static RashkarSeverityStyle severityFor(String? raw) {
    final norm = (raw ?? '').trim().toLowerCase();
    if (norm.contains('extreme') ||
        norm.contains('critical') ||
        norm.contains('very_high') ||
        norm.contains('very high') ||
        norm.contains('unsuitable') ||
        norm.contains('severe') ||
        norm.contains('danger')) {
      return severityBands[3];
    }
    if (norm.contains('high') ||
        norm.contains('caution') ||
        norm.contains('stale') ||
        norm.contains('poor')) {
      return severityBands[2];
    }
    if (norm.contains('moderate') ||
        norm.contains('medium') ||
        norm.contains('partial') ||
        norm.contains('marginal') ||
        norm.contains('attention')) {
      return severityBands[1];
    }
    return severityBands[0];
  }

  /// Botanical tile background colors matching the Figma crop selector cards.
  static Color cropPastelBg(String? cropNameOrCode) {
    final key = (cropNameOrCode ?? '').toLowerCase();
    if (key.contains('cotton')) return const Color(0xFFEDF3E9);
    if (key.contains('soy')) return const Color(0xFFE8F0DF);
    if (key.contains('onion')) return const Color(0xFFF6E9EE);
    if (key.contains('wheat')) return const Color(0xFFFAF0DC);
    if (key.contains('sugar')) return const Color(0xFFE6F2EC);
    if (key.contains('grape')) return const Color(0xFFF0EBF7);
    if (key.contains('tomato')) return const Color(0xFFFBE9E5);
    if (key.contains('jowar') || key.contains('maize') || key.contains('corn')) {
      return const Color(0xFFF9F1DA);
    }
    if (key.contains('rice') || key.contains('paddy')) return const Color(0xFFE4F0EB);
    return mintBg;
  }
}
