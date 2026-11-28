import 'package:flutter/material.dart';

const brandOrange = Color(0xFFFF4D1A);
const brandOrangeDeep = Color(0xFFE2340A);
const goodGreen = Color(0xFF16A34A);
const badRed = Color(0xFFDC2626);

const brandGradient = LinearGradient(
  colors: [brandOrange, brandOrangeDeep],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Barlow Condensed heavy italic, for numbers and headings.
TextStyle display(double size, {FontWeight weight = FontWeight.w900, Color? color, double? spacing}) =>
    TextStyle(
      fontFamily: 'BarlowCondensed',
      fontStyle: FontStyle.italic,
      fontWeight: weight,
      fontSize: size,
      height: 1.0,
      color: color,
      letterSpacing: spacing,
    );

/// Plain upright numbers: readable without shouting.
TextStyle numberStyle(double size, {Color? color, FontWeight weight = FontWeight.w600}) => TextStyle(
      fontFamily: 'Barlow',
      fontWeight: weight,
      fontSize: size,
      height: 1.0,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Small uppercase section label.
TextStyle label(BuildContext context, {Color? color}) => display(15,
    weight: FontWeight.w700,
    spacing: 1.4,
    color: color ?? Theme.of(context).colorScheme.onSurfaceVariant);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: brandOrange, brightness: brightness).copyWith(
    primary: brandOrange,
    onPrimary: Colors.white,
    surface: dark ? const Color(0xFF111112) : const Color(0xFFF5F2EF),
    surfaceContainerLowest: dark ? const Color(0xFF1C1C1F) : Colors.white,
    surfaceContainerHighest: dark ? const Color(0xFF2A2A2E) : const Color(0xFFECE7E3),
  );
  final radius = BorderRadius.circular(16);
  OutlineInputBorder border(Color c, [double w = 2]) =>
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c, width: w));

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Barlow',
    scaffoldBackgroundColor: scheme.surface,
  );
  return base.copyWith(
    // Colours set explicitly: the display styles carry none, and dialog
    // titles (headlineSmall) would otherwise come out white.
    textTheme: base.textTheme.copyWith(
      headlineLarge: display(40, color: scheme.onSurface),
      headlineMedium: display(32, color: scheme.onSurface),
      headlineSmall: display(26, color: scheme.onSurface),
      titleLarge: display(24, weight: FontWeight.w800, color: scheme.onSurface),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: display(30, color: scheme.onSurface, spacing: 0.5),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.6 : 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(brandOrange, 3),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: display(24, weight: FontWeight.w800, spacing: 1),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(display(17, weight: FontWeight.w700)),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant, width: 2)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? brandOrange : null),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : scheme.onSurface),
        // White on the orange selection, else the text colour so unselected
        // icons show on the light theme too.
        iconColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : scheme.onSurface),
        minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
      ),
    ),
    chipTheme: ChipThemeData(
      labelStyle: display(17, weight: FontWeight.w700),
      selectedColor: brandOrange,
      secondaryLabelStyle: display(17, weight: FontWeight.w700, color: Colors.white),
      checkmarkColor: Colors.white,
      side: BorderSide(color: scheme.outlineVariant, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: brandOrange,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Colors.white : scheme.onSurfaceVariant)),
      labelTextStyle: WidgetStatePropertyAll(display(16, weight: FontWeight.w700)),
    ),
  );
}
