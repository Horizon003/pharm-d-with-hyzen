import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

class AppTheme {
  AppTheme._();
  static const fontFamily = 'Manrope';

  static TextTheme _text(Color ink, Color ink2) {
    const f = fontFamily;
    return TextTheme(
      displaySmall: TextStyle(
        fontFamily: f,
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -0.6,
      ),
      headlineMedium: TextStyle(
        fontFamily: f,
        fontSize: 21,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -0.4,
      ),
      headlineSmall: TextStyle(
        fontFamily: f,
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontFamily: f,
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontFamily: f,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontFamily: f,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: f,
        fontSize: 13,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: f,
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: ink2,
      ),
      bodySmall: TextStyle(
        fontFamily: f,
        fontSize: 11,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: ink2,
      ),
      labelLarge: TextStyle(
        fontFamily: f,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontFamily: f,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ink2,
      ),
      labelSmall: TextStyle(
        fontFamily: f,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: ink2,
        letterSpacing: 0.6,
      ),
    );
  }

  static ThemeData light([Color seed = HColors.primary]) =>
      _build(Brightness.light, seed);
  static ThemeData dark([Color seed = HColors.primary]) =>
      _build(Brightness.dark, seed);

  static ThemeData _build(Brightness b, Color seed) {
    final dark = b == Brightness.dark;
    final ink = dark ? HColors.darkInk : HColors.ink;
    final ink2 = dark ? HColors.darkInk2 : HColors.ink2;
    final generated = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    final isBrand = seed.toARGB32() == HColors.primary.toARGB32();
    final bg = dark ? HColors.darkBackground : HColors.background;
    final surface = dark ? HColors.darkSurface : HColors.surface;
    final primary = dark
        ? (isBrand ? HColors.darkPrimary : generated.primary)
        : seed;
    final container = dark
        ? Color.alphaBlend(primary.withValues(alpha: .18), HColors.darkSurface)
        : (isBrand
              ? HColors.primarySoft
              : Color.alphaBlend(seed.withValues(alpha: .14), Colors.white));
    final scheme = generated.copyWith(
      primary: primary,
      onPrimary: dark ? HColors.ink : Colors.white,
      primaryContainer: container,
      onPrimaryContainer: dark ? HColors.darkInk : HColors.slate,
      secondary: dark ? HColors.darkInk2 : HColors.slate,
      secondaryContainer: container,
      onSecondaryContainer: ink,
      onSecondary: dark ? HColors.slateDeep : Colors.white,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: ink2,
      surfaceContainerLowest: dark ? HColors.darkSurface : Colors.white,
      surfaceContainerLow: dark ? HColors.darkSurfaceAlt : HColors.surfaceAlt,
      surfaceContainer: dark ? HColors.darkSurfaceAlt : HColors.surfaceAlt,
      surfaceContainerHigh: dark
          ? const Color(0xFF323232)
          : const Color(0xFFE6E6E4),
      surfaceContainerHighest: dark
          ? const Color(0xFF3B3B3B)
          : const Color(0xFFDCDCD9),
      error: HColors.error,
      outline: dark ? const Color(0x33FFFFFF) : HColors.outlineStrong,
      outlineVariant: dark ? const Color(0x1FFFFFFF) : HColors.outline,
      inverseSurface: dark ? HColors.darkInk : HColors.slate,
      onInverseSurface: dark ? HColors.slate : Colors.white,
    );
    final text = _text(ink, ink2);
    final border = OutlineInputBorder(
      borderRadius: HRadius.all(HRadius.md),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: bg,
      textTheme: text,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: ink,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: HRadius.all(HRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? HColors.darkSurface : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: HColors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: HColors.error, width: 1.6),
        ),
        labelStyle: text.bodyMedium,
        floatingLabelStyle: text.labelMedium?.copyWith(color: scheme.primary),
        hintStyle: text.bodyMedium?.copyWith(
          color: dark ? HColors.darkInk2 : HColors.ink3,
        ),
        errorStyle: text.bodySmall?.copyWith(
          color: HColors.error,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: ink2,
        suffixIconColor: ink2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          textStyle: text.labelLarge?.copyWith(fontSize: 14),
          elevation: 1,
          shadowColor: dark ? Colors.black87 : Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: HRadius.all(HRadius.md)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: HRadius.all(HRadius.lg)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : null,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: ink2,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelMedium,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: ink,
          textStyle: text.labelLarge,
          elevation: 1,
          shadowColor: dark ? Colors.black87 : Colors.black26,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: HRadius.all(HRadius.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          textStyle: text.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.primary,
        labelStyle: text.labelMedium,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: HRadius.all(HRadius.pill)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall!.copyWith(
            color: s.contains(WidgetState.selected) ? scheme.primary : ink2,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 27,
            color: s.contains(WidgetState.selected) ? scheme.primary : ink2,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: dark ? HColors.darkSurfaceAlt : Colors.white,
          foregroundColor: ink,
          minimumSize: const Size(42, 42),
          shape: const CircleBorder(),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(HRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: HRadius.all(HRadius.xl)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HColors.slate,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: HRadius.all(HRadius.md)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
