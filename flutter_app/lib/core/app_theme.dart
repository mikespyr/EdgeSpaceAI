import 'package:flutter/material.dart';

class EdgeColors {
  static const bg = Color(0xFF07131D);
  static const bgDeep = Color(0xFF04101A);
  static const panel = Color(0xFF0D2131);
  static const panel2 = Color(0xFF10283A);
  static const stroke = Color(0xFF1D3E56);
  static const blue = Color(0xFF5AA9FF);
  static const blueStrong = Color(0xFF218BFF);
  static const cyan = Color(0xFF4ED8FF);
  static const green = Color(0xFF54E39A);
  static const amber = Color(0xFFFFC857);
  static const red = Color(0xFFFF6B6B);
  static const text = Color(0xFFF2F7FB);
  static const muted = Color(0xFF93A9B9);
}

class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: EdgeColors.blue,
      brightness: Brightness.dark,
      surface: EdgeColors.panel,
    ).copyWith(
      primary: EdgeColors.blue,
      secondary: EdgeColors.green,
      tertiary: EdgeColors.cyan,
      error: EdgeColors.red,
      surface: EdgeColors.panel,
      surfaceContainerHighest: EdgeColors.panel2,
      outline: EdgeColors.stroke,
      onSurface: EdgeColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: EdgeColors.bg,
      fontFamilyFallback: const ['Roboto', 'Arial'],
      appBarTheme: const AppBarTheme(
        backgroundColor: EdgeColors.bg,
        foregroundColor: EdgeColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: EdgeColors.bgDeep,
        indicatorColor: EdgeColors.blue.withValues(alpha: .18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? EdgeColors.blue : EdgeColors.muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected) ? EdgeColors.blue : EdgeColors.muted,
            )),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: EdgeColors.panel,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: EdgeColors.stroke, width: .7),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EdgeColors.panel2,
        hintStyle: const TextStyle(color: EdgeColors.muted),
        labelStyle: const TextStyle(color: EdgeColors.muted),
        prefixIconColor: EdgeColors.muted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: EdgeColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: EdgeColors.blue, width: 1.3),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: EdgeColors.panel2,
        selectedColor: EdgeColors.blue.withValues(alpha: .22),
        side: const BorderSide(color: EdgeColors.stroke),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: EdgeColors.blueStrong,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EdgeColors.blue,
          side: const BorderSide(color: EdgeColors.blue),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      dividerColor: EdgeColors.stroke,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: EdgeColors.text, fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(color: EdgeColors.text, fontWeight: FontWeight.w800),
        headlineSmall: TextStyle(color: EdgeColors.text, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: EdgeColors.text, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: EdgeColors.text, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: EdgeColors.text),
        bodyMedium: TextStyle(color: EdgeColors.text),
        bodySmall: TextStyle(color: EdgeColors.muted),
        labelLarge: TextStyle(color: EdgeColors.text, fontWeight: FontWeight.w600),
      ),
    );
  }
}
