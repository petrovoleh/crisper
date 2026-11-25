import 'package:flutter/material.dart';

@immutable
class CrisperPalette extends ThemeExtension<CrisperPalette> {
  const CrisperPalette({
    required this.isDark,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceContainer,
    required this.surfaceHigh,
    required this.card,
    required this.border,
    required this.primary,
    required this.primaryAction,
    required this.onPrimary,
    required this.sageChipBg,
    required this.sageChipText,
    required this.terracotta,
    required this.peachChipBg,
    required this.peachChipText,
    required this.ink,
    required this.muted,
    required this.headerGlass,
  });

  final bool isDark;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceContainer;
  final Color surfaceHigh;
  final Color card;
  final Color border;
  final Color primary;
  final Color primaryAction;
  final Color onPrimary;
  final Color sageChipBg;
  final Color sageChipText;
  final Color terracotta;
  final Color peachChipBg;
  final Color peachChipText;
  final Color ink;
  final Color muted;
  final Color headerGlass;

  static const light = CrisperPalette(
    isDark: false,
    surface: Color(0xFFFCF9F4),
    surfaceLow: Color(0xFFF6F3EE),
    surfaceContainer: Color(0xFFF0EDE9),
    surfaceHigh: Color(0xFFEBE8E3),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFEAE4DA),
    primary: Color(0xFF144227),
    primaryAction: Color(0xFF1A4B2E),
    onPrimary: Color(0xFFFFFFFF),
    sageChipBg: Color(0xFFD5F0DC),
    sageChipText: Color(0xFF144227),
    terracotta: Color(0xFFB33B1A),
    peachChipBg: Color(0xFFFCE6DF),
    peachChipText: Color(0xFF8C2507),
    ink: Color(0xFF1C1917),
    muted: Color(0xFF5A5650),
    headerGlass: Color(0xEBFCF9F4),
  );

  static const dark = CrisperPalette(
    isDark: true,
    surface: Color(0xFF161311),
    surfaceLow: Color(0xFF1E1B19),
    surfaceContainer: Color(0xFF26221F),
    surfaceHigh: Color(0xFF302B28),
    card: Color(0xFF211E1B),
    border: Color(0xFF38332E),
    primary: Color(0xFF8BD4A4),
    primaryAction: Color(0xFF3E7B54),
    onPrimary: Color(0xFFF5F2EB),
    sageChipBg: Color(0xFF1E3125),
    sageChipText: Color(0xFF95D5A7),
    terracotta: Color(0xFFE57A58),
    peachChipBg: Color(0xFF38221B),
    peachChipText: Color(0xFFFFB59E),
    ink: Color(0xFFF5F2EB),
    muted: Color(0xFFA8A199),
    headerGlass: Color(0xEB161311),
  );

  @override
  CrisperPalette copyWith({
    bool? isDark,
    Color? surface,
    Color? surfaceLow,
    Color? surfaceContainer,
    Color? surfaceHigh,
    Color? card,
    Color? border,
    Color? primary,
    Color? primaryAction,
    Color? onPrimary,
    Color? sageChipBg,
    Color? sageChipText,
    Color? terracotta,
    Color? peachChipBg,
    Color? peachChipText,
    Color? ink,
    Color? muted,
    Color? headerGlass,
  }) {
    return CrisperPalette(
      isDark: isDark ?? this.isDark,
      surface: surface ?? this.surface,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      card: card ?? this.card,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryAction: primaryAction ?? this.primaryAction,
      onPrimary: onPrimary ?? this.onPrimary,
      sageChipBg: sageChipBg ?? this.sageChipBg,
      sageChipText: sageChipText ?? this.sageChipText,
      terracotta: terracotta ?? this.terracotta,
      peachChipBg: peachChipBg ?? this.peachChipBg,
      peachChipText: peachChipText ?? this.peachChipText,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      headerGlass: headerGlass ?? this.headerGlass,
    );
  }

  @override
  CrisperPalette lerp(ThemeExtension<CrisperPalette>? other, double t) {
    if (other is! CrisperPalette) return this;
    return CrisperPalette(
      isDark: t < 0.5 ? isDark : other.isDark,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryAction: Color.lerp(primaryAction, other.primaryAction, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      sageChipBg: Color.lerp(sageChipBg, other.sageChipBg, t)!,
      sageChipText: Color.lerp(sageChipText, other.sageChipText, t)!,
      terracotta: Color.lerp(terracotta, other.terracotta, t)!,
      peachChipBg: Color.lerp(peachChipBg, other.peachChipBg, t)!,
      peachChipText: Color.lerp(peachChipText, other.peachChipText, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      headerGlass: Color.lerp(headerGlass, other.headerGlass, t)!,
    );
  }
}

extension CrisperContextTheme on BuildContext {
  CrisperPalette get palette =>
      Theme.of(this).extension<CrisperPalette>() ?? CrisperPalette.light;
}

class CrisperTypography {
  static const String serif = 'EditorialSerif';
  static const String sans = 'PlusJakartaSans';

  static TextStyle displayItalic(Color color) => TextStyle(
        fontFamily: serif,
        fontSize: 34,
        height: 1.18,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle headlineLg(Color color) => TextStyle(
        fontFamily: serif,
        fontSize: 28,
        height: 1.22,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle headlineMd(Color color) => TextStyle(
        fontFamily: serif,
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle headlineSm(Color color) => TextStyle(
        fontFamily: serif,
        fontSize: 20,
        height: 1.28,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle titleLg(Color color) => TextStyle(
        fontFamily: sans,
        fontSize: 17,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle titleMd(Color color) => TextStyle(
        fontFamily: sans,
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle bodyMd(Color color) => TextStyle(
        fontFamily: sans,
        fontSize: 14,
        height: 1.48,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodySm(Color color) => TextStyle(
        fontFamily: sans,
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle labelLg(Color color) => TextStyle(
        fontFamily: sans,
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color,
      );

  static TextStyle labelMd(Color color) => TextStyle(
        fontFamily: sans,
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color,
      );

  static TextStyle labelSm(Color color) => TextStyle(
        fontFamily: sans,
        fontSize: 11,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: color,
      );

  static TextStyle tabular(
    Color color, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    String fontFamily = sans,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

class CrisperTheme {
  static ThemeData build(CrisperPalette p) {
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.primaryAction,
      onPrimary: p.onPrimary,
      secondary: p.terracotta,
      onSecondary: Colors.white,
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: CrisperTypography.sans,
      scaffoldBackgroundColor: p.surface,
      colorScheme: colorScheme,
      extensions: [p],
      dividerColor: p.border,
      splashFactory: InkSparkle.splashFactory,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? p.surfaceHigh : p.ink,
        contentTextStyle: CrisperTypography.bodyMd(
          p.isDark ? p.ink : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData get light => build(CrisperPalette.light);
  static ThemeData get dark => build(CrisperPalette.dark);
}
