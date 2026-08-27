import 'package:flutter/material.dart';

/// Proposed semantic colors for Ultimate Remote.
///
/// These values come from the PHASE 5 proposed design system and are not
/// official Ultimate Solutions brand guidelines until separately approved.
@immutable
class UltimateThemeExtension extends ThemeExtension<UltimateThemeExtension> {
  const UltimateThemeExtension({
    required this.brandNavy,
    required this.brandTeal,
    required this.brandBlue,
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textInverse,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.border,
    required this.focus,
  });

  final Color brandNavy;
  final Color brandTeal;
  final Color brandBlue;
  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textInverse;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color border;
  final Color focus;

  static const light = UltimateThemeExtension(
    brandNavy: Color(0xFF102A43),
    brandTeal: Color(0xFF0F766E),
    brandBlue: Color(0xFF2563EB),
    background: Color(0xFFF6F8FB),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFEEF2F6),
    textPrimary: Color(0xFF102A43),
    textSecondary: Color(0xFF52606D),
    textInverse: Color(0xFFFFFFFF),
    success: Color(0xFF166534),
    warning: Color(0xFF92400E),
    error: Color(0xFFB91C1C),
    info: Color(0xFF1D4ED8),
    border: Color(0xFFCBD5E1),
    focus: Color(0xFF7C3AED),
  );

  static const dark = UltimateThemeExtension(
    brandNavy: Color(0xFF102A43),
    brandTeal: Color(0xFF5EEAD4),
    brandBlue: Color(0xFF93C5FD),
    background: Color(0xFF0B1320),
    surface: Color(0xFF162235),
    surfaceSubtle: Color(0xFF20314A),
    textPrimary: Color(0xFFF5F7FA),
    textSecondary: Color(0xFFB8C4D3),
    textInverse: Color(0xFF0B1320),
    success: Color(0xFF86EFAC),
    warning: Color(0xFFFCD34D),
    error: Color(0xFFFCA5A5),
    info: Color(0xFF93C5FD),
    border: Color(0xFF334155),
    focus: Color(0xFFC4B5FD),
  );

  @override
  UltimateThemeExtension copyWith({
    Color? brandNavy,
    Color? brandTeal,
    Color? brandBlue,
    Color? background,
    Color? surface,
    Color? surfaceSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textInverse,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? border,
    Color? focus,
  }) {
    return UltimateThemeExtension(
      brandNavy: brandNavy ?? this.brandNavy,
      brandTeal: brandTeal ?? this.brandTeal,
      brandBlue: brandBlue ?? this.brandBlue,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textInverse: textInverse ?? this.textInverse,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      border: border ?? this.border,
      focus: focus ?? this.focus,
    );
  }

  @override
  UltimateThemeExtension lerp(
      ThemeExtension<UltimateThemeExtension>? other, double t) {
    if (other is! UltimateThemeExtension) {
      return this;
    }
    return UltimateThemeExtension(
      brandNavy: Color.lerp(brandNavy, other.brandNavy, t)!,
      brandTeal: Color.lerp(brandTeal, other.brandTeal, t)!,
      brandBlue: Color.lerp(brandBlue, other.brandBlue, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      border: Color.lerp(border, other.border, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
    );
  }
}

/// Shared non-color tokens. Keep raw values out of new Foundation widgets.
class UltimateDesignTokens {
  UltimateDesignTokens._();

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 24;
  static const double spacing2xl = 32;
  static const double spacing3xl = 48;

  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 16;
  static const double radiusPill = 999;

  static const double controlHeightCompact = 32;
  static const double controlHeightDefault = 40;
  static const double controlHeightTouch = 48;
  static const double focusRingWidth = 2;
  static const double focusRingOffset = 2;

  static const Duration motionFast = Duration(milliseconds: 120);
  static const Duration motionStandard = Duration(milliseconds: 200);
  static const Duration motionSlow = Duration(milliseconds: 320);

  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle bodyLarge = TextStyle(fontSize: 16);
  static const TextStyle body = TextStyle(fontSize: 14);
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle caption = TextStyle(fontSize: 12);
  static const TextStyle code = TextStyle(
    fontSize: 13,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}
