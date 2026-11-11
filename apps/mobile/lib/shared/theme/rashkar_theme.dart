import 'package:flutter/material.dart';

import 'rashkar_colors.dart';

/// Unified Material 3 theme implementing the Rashkar Figma Make visual system
/// across CropNet Web and Mobile screens.
class RashkarTheme {
  const RashkarTheme._();

  static const List<String> fontFallbackStack = [
    'Inter',
    'Plus Jakarta Sans',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static ThemeData light() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: RashkarColors.forestTint,
      onPrimary: Colors.white,
      primaryContainer: RashkarColors.mintBg,
      onPrimaryContainer: RashkarColors.forest,
      secondary: RashkarColors.marigold,
      onSecondary: Colors.white,
      secondaryContainer: RashkarColors.marigoldTint,
      onSecondaryContainer: RashkarColors.marigoldInk,
      tertiary: RashkarColors.highBar,
      onTertiary: Colors.white,
      tertiaryContainer: RashkarColors.highBg,
      onTertiaryContainer: RashkarColors.highFg,
      error: RashkarColors.extremeBar,
      onError: Colors.white,
      errorContainer: RashkarColors.extremeBg,
      onErrorContainer: RashkarColors.extremeFg,
      surface: RashkarColors.surface,
      onSurface: RashkarColors.ink,
      surfaceContainerLowest: RashkarColors.surface,
      surfaceContainerLow: RashkarColors.canvas,
      surfaceContainer: RashkarColors.surfaceSubtle,
      surfaceContainerHigh: RashkarColors.deskBg,
      onSurfaceVariant: RashkarColors.mutedInk,
      outline: RashkarColors.border,
      outlineVariant: RashkarColors.borderStrong,
      shadow: Colors.black.withValues(alpha: 0.05),
    );

    const baseTextTheme = TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: RashkarColors.ink,
        height: 1.1,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: RashkarColors.ink,
        height: 1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: RashkarColors.ink,
        height: 1.25,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: RashkarColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: RashkarColors.ink,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: RashkarColors.ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: RashkarColors.ink,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: RashkarColors.ink,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: RashkarColors.mutedInk,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: RashkarColors.ink,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: RashkarColors.mutedInk,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: RashkarColors.mutedInk,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: RashkarColors.canvas,
      canvasColor: RashkarColors.canvas,
      textTheme: baseTextTheme.apply(
        fontFamilyFallback: fontFallbackStack,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: RashkarColors.surface,
        foregroundColor: RashkarColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: RashkarColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: RashkarColors.border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: RashkarColors.border,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RashkarColors.forestTint,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RashkarColors.forestTint,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: RashkarColors.surface,
          foregroundColor: RashkarColors.ink,
          side: const BorderSide(color: RashkarColors.borderStrong, width: 1.2),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RashkarColors.forest,
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RashkarColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: RashkarColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: RashkarColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: RashkarColors.forestTint, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: RashkarColors.extremeBar),
        ),
        labelStyle: const TextStyle(color: RashkarColors.mutedInk, fontSize: 14.5),
        hintStyle: const TextStyle(color: RashkarColors.subtleInk, fontSize: 14.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: RashkarColors.surface,
        selectedColor: RashkarColors.mintBg,
        secondarySelectedColor: RashkarColors.mintBg,
        checkmarkColor: RashkarColors.forest,
        disabledColor: RashkarColors.surfaceSubtle,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: const BorderSide(color: RashkarColors.border),
        shape: const StadiumBorder(),
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? RashkarColors.forest : RashkarColors.ink,
          );
        }),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: RashkarColors.forest,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: RashkarColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: RashkarColors.mintBg,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? RashkarColors.forest : RashkarColors.mutedInk,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? RashkarColors.forest : RashkarColors.mutedInk,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: RashkarColors.forest,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: RashkarColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: RashkarColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
