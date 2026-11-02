import 'package:flutter/material.dart';
import 'package:rectora/domain/progression/rewards.dart';

@immutable
class RectoraPalette {
  const RectoraPalette({
    required this.brightness,
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.ink,
    required this.muted,
    required this.copper,
    required this.copperInk,
    required this.pine,
    required this.rose,
    required this.grid,
    required this.emptyCell,
  });

  final Brightness brightness;
  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceHigh;
  final Color line;
  final Color ink;
  final Color muted;
  final Color copper;
  final Color copperInk;
  final Color pine;
  final Color rose;
  final Color grid;
  final Color emptyCell;

  static const dark = RectoraPalette(
    brightness: Brightness.dark,
    background: Color(0xFF141A22),
    backgroundAlt: Color(0xFF1B2330),
    surface: Color(0xFF243041),
    surfaceHigh: Color(0xFF314055),
    line: Color(0xFF46566C),
    ink: Color(0xFFF4EFE6),
    muted: Color(0xFFC5D0DC),
    copper: Color(0xFFE0975C),
    copperInk: Color(0xFF2A160C),
    pine: Color(0xFF8FBF7A),
    rose: Color(0xFFE07A72),
    grid: Color(0xFF10151C),
    emptyCell: Color(0xFF2A3546),
  );

  static const light = RectoraPalette(
    brightness: Brightness.light,
    background: Color(0xFFF4EFE6),
    backgroundAlt: Color(0xFFFFFBF6),
    surface: Color(0xFFFFFBF6),
    surfaceHigh: Color(0xFFF0E4D4),
    line: Color(0xFFD9CBB8),
    ink: Color(0xFF1C212B),
    muted: Color(0xFF5C6573),
    copper: Color(0xFFB8612E),
    copperInk: Color(0xFFFFF8F2),
    pine: Color(0xFF2F7D4F),
    rose: Color(0xFFA33B3B),
    grid: Color(0xFFE7DDD0),
    emptyCell: Color(0xFFF7F1E8),
  );

  static final _styled = <(Brightness, String), RectoraPalette>{};

  /// This palette with the empty cells tinted for an unlocked board style.
  /// Kept per style, so a board repaints only when the style really changes.
  RectoraPalette forBoard(String style, int xp) {
    final tint = switch (style) {
      'ivory' => const Color(0xFFF3E6C8),
      'pine' => pine,
      'archive' => const Color(0xFFD6B15E),
      _ => null,
    };
    if (tint == null || !styleUnlocked(xp, style)) return this;
    return _styled.putIfAbsent((brightness, style), () {
      Color mix(Color base) => Color.lerp(base, tint, 0.2)!;
      return RectoraPalette(
        brightness: brightness,
        background: background,
        backgroundAlt: backgroundAlt,
        surface: surface,
        surfaceHigh: mix(surfaceHigh),
        line: line,
        ink: ink,
        muted: muted,
        copper: copper,
        copperInk: copperInk,
        pine: pine,
        rose: rose,
        grid: grid,
        emptyCell: mix(emptyCell),
      );
    });
  }
}

class RectoraTheme extends ThemeExtension<RectoraTheme> {
  const RectoraTheme(this.palette);

  final RectoraPalette palette;

  static RectoraPalette of(BuildContext context) {
    return Theme.of(context).extension<RectoraTheme>()!.palette;
  }

  @override
  RectoraTheme copyWith({RectoraPalette? palette}) {
    return RectoraTheme(palette ?? this.palette);
  }

  @override
  RectoraTheme lerp(ThemeExtension<RectoraTheme>? other, double t) => this;
}

const regionFills = <Color>[
  Color(0xFFD9895B),
  Color(0xFF6E9E8A),
  Color(0xFF7F93C4),
  Color(0xFFD6B15E),
  Color(0xFFB583B0),
  Color(0xFFD97870),
  Color(0xFF8AAA62),
  Color(0xFF5EABBE),
];

const numberInk = Color(0xFF1A140F);

/// Shared spacing, radii, and motion. Screens should use these instead of
/// one-off values when they introduce new layout.
class RectoraTokens {
  static const cardRadius = 22.0;
  static const nodeRadius = 18.0;
  static const pagePadding = 20.0;
  static const motion = Duration(milliseconds: 220);
  static const reveal = Duration(milliseconds: 420);
  static const ease = Curves.easeOutCubic;
}

ThemeData buildRectoraTheme(RectoraPalette palette) {
  final scheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.copper,
    onPrimary: palette.copperInk,
    secondary: palette.pine,
    onSecondary: numberInk,
    error: palette.rose,
    onError: palette.brightness == Brightness.dark ? numberInk : Colors.white,
    surface: palette.surface,
    onSurface: palette.ink,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    fontFamily: 'Roboto',
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: palette.ink,
      displayColor: palette.ink,
      fontFamily: 'Roboto',
    ),
    extensions: [RectoraTheme(palette)],
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
