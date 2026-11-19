import 'package:flutter/material.dart';

/// PHARM D WITH HYZEN design tokens.
///
/// Reference-led pastel surfaces, geometric typography and charcoal controls.
/// Semantic status colors and document annotation ink remain meaningful.
class HColors {
  HColors._();
  // Brand
  static const primary = Color(0xFF18181B);
  static const primaryDeep = Color(0xFF121216);
  static const primarySoft = Color(0xFFE7E0FA);
  static const slate = Color(0xFF25252B);
  static const slateDeep = Color(0xFF17171C);
  static const teal = Color(0xFF66717B);
  static const mint = Color(0xFFBEE8D4);
  static const onPrimary = Colors.white;

  // Ink
  static const ink = Color(0xFF121216);
  static const ink2 = Color(0xFF68686F);
  static const ink3 = Color(0xFF76767C);

  // Surfaces (light)
  static const background = Color(0xFFFAFAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF1F1F4);
  static const outline = Color(0xFFE7E7EB);
  static const outlineStrong = Color(0xFFC5C5CC);

  // Warm nude accents: confined to content surfaces, never text on pale ink.
  static const nudePeach = Color(0xFFFFCD89);
  static const nudeSand = Color(0xFFE4DBFA);
  static const darkPeach = Color(0xFF49382D);

  static const lavender = Color(0xFFB99BFA);
  static const blue = Color(0xFFA8CAFA);
  static const pink = Color(0xFFF2B3F2);
  static const apricot = Color(0xFFFFC568);
  static const sage = Color(0xFFB8DFCD);

  // Status
  static const success = Color(0xFF15885A);
  static const warning = Color(0xFFB7791F);
  static const error = Color(0xFFC0392B);
  static const info = Color(0xFF64646F);

  // Dark
  static const darkBackground = Color(0xFF171411);
  static const darkSurface = Color(0xFF231F1B);
  static const darkSurfaceAlt = Color(0xFF322B25);
  static const darkInk = Color(0xFFF7EFE5);
  static const darkInk2 = Color(0xFFC3B6A7);
  static const darkPrimary = Color(0xFFE7D2BC);

  /// Restrained module accents – used on small icon badges only.
  static const notes = Color(0xFF487866);
  static const mcqs = Color(0xFF78629B);
  static const papers = Color(0xFF527692);
  static const special = Color(0xFF945E7F);
  static const lectures = Color(0xFF95693A);
}

/// Four-point rhythm; touch targets remain at least 48dp.
class HSpace {
  HSpace._();
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 20.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const screen = 16.0;
}

class HRadius {
  HRadius._();
  static const sm = 10.0;
  static const md = 20.0;
  static const lg = 26.0;
  static const xl = 32.0;
  static const pill = 999.0;
  static BorderRadius all(double r) => BorderRadius.circular(r);
}

class HMotion {
  HMotion._();
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 360);
  static const curve = Cubic(0.22, 1, 0.36, 1);
  static Duration duration(BuildContext context, [Duration value = fast]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}

class HShadow {
  HShadow._();
  static const soft = [
    BoxShadow(color: Color(0x0D1A1A1A), blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const lifted = [
    BoxShadow(color: Color(0x161A1A1A), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const glow = [
    BoxShadow(color: Color(0x261C1C1E), blurRadius: 4, offset: Offset(0, 1)),
  ];
}

/// Quiet graphite hero gradient for selected surfaces only.
const hSlateGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF111111), Color(0xFF111111), Color(0xFF111111)],
  stops: [0, .62, 1],
);

/// Keep module colours legible on both opaque surface themes.
Color adaptiveAccent(BuildContext context, Color color) {
  final theme = Theme.of(context);
  if (color == HColors.primary ||
      color == HColors.primaryDeep ||
      color == HColors.notes) {
    return theme.colorScheme.primary;
  }
  if (color == HColors.primarySoft) return theme.colorScheme.primaryContainer;
  if (theme.brightness != Brightness.dark) return color;
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness(hsl.lightness < 0.68 ? 0.68 : hsl.lightness)
      .toColor();
}

/// Static canvas, matching the supplied white/peach reference background.
const hPageGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF0EBFA), Color(0xFFFFF4E9), Color(0xFFEBF5F5)],
  stops: [0, .48, 1],
);
const hStudyGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFB8DFCD), Color(0xFFDFE3AA), Color(0xFFF1DEB3)],
);
const hFocusGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFC0A5FC), Color(0xFFA995F1)],
);
const hLessonGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFCD9EA), Color(0xFFF8C5DF)],
);
