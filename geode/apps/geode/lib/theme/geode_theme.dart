import 'package:flutter/material.dart';

/// One material vocabulary shared by the scene's crisp, readable controls.
abstract final class GeodeTokens {
  static const ink = Color(0xFFF1F8FA);
  static const muted = Color(0xFFAEC7D0);
  static const accent = Color(0xFFD9F3DF);
  static const deep = Color(0xFF061B22);
  static const ice = Color(0xFFADDCEB);
  static const radius = 28.0;
  static const minTarget = 48.0;

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: deep,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: ice,
          surface: Color(0xFF102D38),
          onSurface: ink,
          onPrimary: deep,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: ['serif'],
            color: ink,
            fontSize: 66,
            height: 1.04,
            fontWeight: FontWeight.w400,
            letterSpacing: -2.6,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: ['serif'],
            color: ink,
            fontSize: 46,
            height: 1.06,
            fontWeight: FontWeight.w400,
            letterSpacing: -1.4,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: ['serif'],
            color: ink,
            fontSize: 34,
            height: 1.12,
            fontWeight: FontWeight.w400,
            letterSpacing: -.8,
          ),
          titleLarge: TextStyle(color: ink, fontSize: 23, height: 1.2, fontWeight: FontWeight.w500),
          titleMedium: TextStyle(color: ink, fontSize: 16, height: 1.3, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: ink, fontSize: 14, height: 1.3, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: ink, fontSize: 15, height: 1.5),
          bodyMedium: TextStyle(color: muted, fontSize: 13, height: 1.5),
          bodySmall: TextStyle(color: muted, fontSize: 12, height: 1.4),
          labelLarge: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: .15),
          labelMedium: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w500),
          labelSmall: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.w500),
        ),
        iconTheme: const IconThemeData(color: ink, size: 22),
        dividerColor: const Color(0x26C7E8F2),
        splashFactory: InkRipple.splashFactory,
        sliderTheme: SliderThemeData(
          activeTrackColor: accent,
          inactiveTrackColor: ice.withValues(alpha: .16),
          thumbColor: ink,
          overlayColor: ice.withValues(alpha: .13),
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 3),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 23),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? deep : muted),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? accent : ice.withValues(alpha: .14)),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      );
}
