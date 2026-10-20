import 'package:flutter/material.dart';

/// Design tokens, the same as the web app's tokens.css: a night gym, green-black surfaces in
/// three tone steps instead of shadows, and one green for the muscles worked and the main action.
abstract final class V {
  // surfaces
  static const bg = Color(0xFF0B1213);
  static const bg2 = Color(0xFF111A1B);
  static const bg3 = Color(0xFF182324);
  static const tabBar = Color(0xFF080E0F);

  // ink
  static const ink = Color(0xFFF1F4F2);
  static const muted = Color(0xFF8E9A97);
  static const faint = Color(0xFF56625F);
  static const line = Color(0x1AF1F4F2);
  static const lineStrong = Color(0x33F1F4F2);

  // Vitalize green: muscles being worked, the primary action, the one active marker
  static const accent = Color(0xFF5FC774);
  static const accentPressed = Color(0xFF52B166);
  static const accentDeep = Color(0xFF1E5A4C);
  static const accentInk = Color(0xFF06200F);
  static const brandTeal = Color(0xFF2A5B60);

  // destructive actions: a muted red that reads on the dark floor without shouting
  static const danger = Color(0xFFEF7A6A);

  // the figure
  static const muscle = Color(0xFF1D2829);
  static const musclePressed = Color(0xFF283536);
  static const silhouette = Color(0xFF141D1E);

  static const display = 'Prompt';
  static const ui = 'BeVietnamPro';
  static const mono = 'JetBrainsMono';

  static const rControl = 4.0;
  static const rSheet = 14.0;
  static const pad = 20.0;
  static const tabBarH = 60.0;

  static const easeExpo = Cubic(0.16, 1, 0.3, 1);
  static const easeDraw = Cubic(0.62, 0.04, 0.22, 1);
  static const easeSwift = Cubic(0.2, 0.8, 0.2, 1);
  static const easeIn = Cubic(0.55, 0, 0.85, 0.35);

  /// Mix of two colours, like CSS `color-mix(in srgb, a p%, b)`.
  static Color mix(Color a, double p, Color b) => Color.lerp(b, a, p)!;
}

/// Text styles. Sizes, weights and line heights follow the CSS; letter spacing is given in em,
/// as in the CSS, and converted to pixels.
abstract final class VT {
  static TextStyle ui(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
    Color color = V.ink,
    double em = -0.005,
  }) => TextStyle(
    fontFamily: V.ui,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
    letterSpacing: em * size,
  );

  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w600,
    double height = 1.2,
    Color color = V.ink,
    double em = -0.02,
  }) => TextStyle(
    fontFamily: V.display,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
    letterSpacing: em * size,
  );

  /// Numbers: tabular figures in the monospace face.
  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.2,
    Color color = V.ink,
  }) => TextStyle(
    fontFamily: V.mono,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
    letterSpacing: -0.02 * size,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Section heading inside long screens: sentence case, quiet, ruled underneath.
  static final sectionTitle = ui(13, weight: FontWeight.w600, height: 1.2, color: V.muted);
  static final body = ui(15);
  static final hint = ui(13, height: 1.4, color: V.muted);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: V.ui,
    scaffoldBackgroundColor: V.bg,
    colorScheme: const ColorScheme.dark(
      primary: V.accent,
      onPrimary: V.accentInk,
      surface: V.bg,
      onSurface: V.ink,
      secondary: V.accent,
      error: V.danger,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: V.accent),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: V.ink, displayColor: V.ink, fontFamily: V.ui),
  );
}
