import 'package:flutter/material.dart';
import 'package:cropnet_mobile/shared/theme/rashkar_tokens.dart';

/// RASHKAR Design Language - Material 3 Theme Integration
abstract final class RashkarTheme {
  static ThemeData get theme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: RashkarColors.forest,
      onPrimary: RashkarColors.white,
      primaryContainer: RashkarColors.leafSoft,
      onPrimaryContainer: RashkarColors.forestDark,
      secondary: RashkarColors.leaf,
      onSecondary: RashkarColors.white,
      secondaryContainer: RashkarColors.leafSoft,
      onSecondaryContainer: RashkarColors.forest,
      tertiary: RashkarColors.amber,
      onTertiary: RashkarColors.ink,
      error: RashkarColors.risk,
      onError: RashkarColors.white,
      errorContainer: RashkarColors.riskSoft,
      onErrorContainer: RashkarColors.riskText,
      surface: RashkarColors.white,
      onSurface: RashkarColors.ink,
      surfaceContainerHighest: RashkarColors.sand,
      outline: RashkarColors.line,
      outlineVariant: RashkarColors.line,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: RashkarTypography.primaryFont,
      fontFamilyFallback: RashkarTypography.fontFallbacks,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: RashkarColors.cream,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: RashkarColors.ink),
        bodyMedium: TextStyle(fontSize: 16, height: 1.45, color: RashkarColors.ink),
        bodySmall: TextStyle(fontSize: 13, height: 1.4, color: RashkarColors.muted),
      ),
      dividerColor: RashkarColors.line,
      dividerTheme: const DividerThemeData(
        color: RashkarColors.line,
        thickness: 1.0,
        space: 1.0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: RashkarColors.forest,
        foregroundColor: RashkarColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: RashkarTypography.primaryFont,
          fontSize: 19.0,
          fontWeight: FontWeight.w700,
          color: RashkarColors.white,
        ),
      ),
      cardTheme: const CardThemeData(
        color: RashkarColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: RashkarRadii.cardBorderRadius,
          side: BorderSide(color: RashkarColors.line, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RashkarColors.forest,
          foregroundColor: RashkarColors.white,
          minimumSize: const Size(double.infinity, RashkarSpacing.primaryButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: RashkarRadii.buttonBorderRadius,
          ),
          textStyle: const TextStyle(
            fontFamily: RashkarTypography.primaryFont,
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: RashkarColors.white,
          foregroundColor: RashkarColors.forest,
          minimumSize: const Size(double.infinity, RashkarSpacing.primaryButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          elevation: 0,
          side: const BorderSide(
            color: RashkarColors.line,
            width: 1.0,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: RashkarRadii.buttonBorderRadius,
          ),
          textStyle: const TextStyle(
            fontFamily: RashkarTypography.primaryFont,
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RashkarColors.forest,
          textStyle: const TextStyle(
            fontFamily: RashkarTypography.primaryFont,
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: RashkarColors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        border: OutlineInputBorder(
          borderRadius: RashkarRadii.inputBorderRadius,
          borderSide: BorderSide(color: RashkarColors.line, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: RashkarRadii.inputBorderRadius,
          borderSide: BorderSide(color: RashkarColors.line, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: RashkarRadii.inputBorderRadius,
          borderSide: BorderSide(color: RashkarColors.leaf, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: RashkarRadii.inputBorderRadius,
          borderSide: BorderSide(color: RashkarColors.risk, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: RashkarColors.muted,
          fontSize: 15.0,
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: RashkarColors.sand,
        selectedColor: RashkarColors.forest,
        secondarySelectedColor: RashkarColors.forest,
        disabledColor: RashkarColors.sand,
        labelStyle: TextStyle(
          fontFamily: RashkarTypography.primaryFont,
          fontSize: 13.0,
          fontWeight: FontWeight.w500,
          color: RashkarColors.ink,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: RashkarTypography.primaryFont,
          fontSize: 13.0,
          fontWeight: FontWeight.w600,
          color: RashkarColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: RashkarRadii.pillBorderRadius,
          side: BorderSide(color: Colors.transparent),
        ),
      ),
    );
  }
}
