import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';
import 'page_transitions.dart';

/// Light-only, reference-led education UI. Legacy preferences stay stored.
class AppTheme {
  AppTheme._();
  static const fontFamily = 'Outfit';
  static ThemeData light([Color seed = HColors.primary]) {
    const ink = HColors.ink, muted = HColors.ink2;
    TextStyle type(
      double size,
      FontWeight weight, {
      Color color = ink,
      double height = 1.4,
    }) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
    final text = TextTheme(
      displaySmall: type(30, FontWeight.w600, height: 1.18),
      headlineMedium: type(24, FontWeight.w600, height: 1.22),
      headlineSmall: type(20, FontWeight.w600, height: 1.3),
      titleLarge: type(16, FontWeight.w600),
      titleMedium: type(14, FontWeight.w600),
      titleSmall: type(13, FontWeight.w500),
      bodyLarge: type(14, FontWeight.w500),
      bodyMedium: type(13, FontWeight.w500, height: 1.5),
      bodySmall: type(12, FontWeight.w500, color: muted),
      labelLarge: type(12, FontWeight.w500),
      labelMedium: type(11, FontWeight.w500, color: muted),
      labelSmall: type(10, FontWeight.w400, color: muted),
    );
    const scheme = ColorScheme.light(
      primary: HColors.primary,
      onPrimary: Colors.white,
      primaryContainer: HColors.primarySoft,
      onPrimaryContainer: ink,
      secondary: HColors.ink2,
      onSecondary: Colors.white,
      secondaryContainer: HColors.surfaceAlt,
      onSecondaryContainer: ink,
      tertiary: HColors.lectures,
      onTertiary: Colors.white,
      tertiaryContainer: HColors.pink,
      onTertiaryContainer: ink,
      surface: HColors.surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLowest: HColors.background,
      surfaceContainerLow: HColors.surface,
      surfaceContainer: HColors.surfaceAlt,
      surfaceContainerHigh: Color(0xFFECECF0),
      surfaceContainerHighest: Color(0xFFE4E4EA),
      surfaceTint: Colors.transparent,
      outline: HColors.outlineStrong,
      outlineVariant: HColors.outline,
      error: HColors.error,
      onError: Colors.white,
      inverseSurface: HColors.ink,
      onInverseSurface: Colors.white,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: HColors.outline),
    );
    ButtonStyle button({bool outlined = false}) => FilledButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tapTargetSize: MaterialTapTargetSize.padded,
      foregroundColor: outlined ? ink : Colors.white,
      backgroundColor: outlined ? Colors.transparent : ink,
      textStyle: text.labelLarge,
      elevation: 0,
      shape: const StadiumBorder(),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: HColors.background,
      iconTheme: const IconThemeData(size: 20, color: ink),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: ink,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HRadius.lg),
          side: const BorderSide(color: HColors.outline),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        minLeadingWidth: 36,
        horizontalTitleGap: 12,
        minVerticalPadding: 8,
        iconColor: ink,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: ink, width: 1.2),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: HColors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: HColors.error),
        ),
        hintStyle: text.bodyMedium?.copyWith(color: muted),
        labelStyle: text.bodyMedium,
        floatingLabelStyle: text.labelMedium,
        errorStyle: text.bodySmall?.copyWith(color: HColors.error),
        prefixIconColor: ink,
        suffixIconColor: muted,
      ),
      filledButtonTheme: FilledButtonThemeData(style: button()),
      elevatedButtonTheme: ElevatedButtonThemeData(style: button()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button(outlined: true).copyWith(
          side: const WidgetStatePropertyAll(
            BorderSide(color: HColors.outlineStrong),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: text.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(34, 34),
          iconSize: 18,
          padding: const EdgeInsets.all(8),
          tapTargetSize: MaterialTapTargetSize.padded,
          backgroundColor: Colors.white.withValues(alpha: .72),
          foregroundColor: ink,
          side: const BorderSide(color: HColors.outline),
          shape: const CircleBorder(),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        elevation: 1,
        shape: StadiumBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: HColors.surfaceAlt,
        selectedColor: HColors.primarySoft,
        labelStyle: text.labelMedium?.copyWith(color: ink),
        checkmarkColor: ink,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ink,
        unselectedLabelColor: muted,
        indicatorColor: ink,
        dividerColor: HColors.outline,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelMedium,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ink,
        linearTrackColor: Color(0x55FFFFFF),
        circularTrackColor: HColors.surfaceAlt,
      ),
      dividerTheme: const DividerThemeData(
        color: HColors.outline,
        space: 1,
        thickness: .8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: HyzenPageTransitions(),
          TargetPlatform.iOS: HyzenPageTransitions(),
        },
      ),
    );
  }

  /// Compatibility for old callers; the product is light-only.
  static ThemeData dark([Color seed = HColors.primary]) => light(seed);
}
