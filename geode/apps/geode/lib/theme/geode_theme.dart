import 'package:flutter/material.dart';

/// One material vocabulary shared by the scene's crisp, readable controls.
abstract final class GeodeTokens {
  static const ink = Color(0xFFF3F1DD);
  static const muted = Color(0xFFBAC7AD);
  static const accent = Color(0xFFD7DEAE);
  static const deep = Color(0xFF101E18);
  static const ice = Color(0xFFA7BD8A);
  static const lilac = Color(0xFFCFBB89);
  static const radius = 28.0;
  static const minTarget = 48.0;

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: deep,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: ice,
          surface: Color(0xFF20382B),
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
        dividerColor: const Color(0x36687F51),
        splashFactory: InkRipple.splashFactory,
        sliderTheme: SliderThemeData(
          activeTrackColor: accent,
          inactiveTrackColor: ice.withValues(alpha: .16),
          thumbColor: ink,
          overlayColor: ice.withValues(alpha: .13),
          trackHeight: 10,
          trackShape: const RoundedRectSliderTrackShape(),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 23),
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF182C22),
          surfaceTintColor: Colors.transparent, elevation: 0, centerTitle: false),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF2D4432),
          selectedColor: const Color(0xFF607550),
          disabledColor: const Color(0xFF263A2C),
          side: const BorderSide(color: Color(0xFF71865B)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          labelStyle: const TextStyle(color: ink, fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF233A2C),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30),
            side: const BorderSide(color: Color(0xFF6B7C53))),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1F3528), surfaceTintColor: Colors.transparent,
          dragHandleColor: Color(0xFF9BAD82),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            side: BorderSide(color: Color(0xFF65794D))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: const Color(0xFF253F2E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF65794D))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF65794D))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: accent)),
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
