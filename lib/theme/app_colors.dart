import 'package:flutter/material.dart';
import 'app_semantic_colors.dart';

/// Light-mode palette values. Deep academic blue as primary, warm gold as accent.
class _Light {
  static const Color primary = Color(0xFF1B3A8C);
  static const Color primaryDark = Color(0xFF102359);
  static const Color primaryLight = Color(0xFF3D5BB8);

  static const Color accent = Color(0xFFF2A93B);
  static const Color accentDark = Color(0xFFD98A1A);

  static const Color success = Color(0xFF2E9E5B);
  static const Color successBg = Color(0xFFE4F6EC);

  static const Color warning = Color(0xFFE0A420);
  static const Color warningBg = Color(0xFFFCF3DC);

  static const Color danger = Color(0xFFDD4B4B);
  static const Color dangerBg = Color(0xFFFBE7E7);

  static const Color info = Color(0xFF2F86D6);
  static const Color infoBg = Color(0xFFE6F2FC);

  // Application-status progression (ordinal blue ramp: light -> deep).
  // Validated with the dataviz skill's palette checker so adjacent steps
  // stay visually distinct for color-vision-deficient readers.
  static const Color statusSubmitted = Color(0xFF5B8FE0);
  static const Color statusSubmittedBg = Color(0xFFEAF1FC);
  static const Color statusVerifying = Color(0xFF2F6FC4);
  static const Color statusVerifyingBg = Color(0xFFE1EBFA);
  static const Color statusReviewing = Color(0xFF1B3A8C);
  static const Color statusReviewingBg = Color(0xFFE8EAF6);

  static const Color neutralBg = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE4E8F0);

  static const Color textPrimary = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color cardShadow = Color(0x14101828);

  // Glassmorphism: frosted panels sit on top of ambient gradient
  // backgrounds, so these need to read as translucent white, not solid.
  static const Color glassSurface = Color(0xCCFFFFFF);
  static const Color glassSurfaceStrong = Color(0xE6FFFFFF);
  static const Color glassBorder = Color(0x99FFFFFF);
}

/// Dark-mode palette values. Same hues as light mode, re-stepped for a dark
/// surface (own steps, validated separately — not an automatic inversion).
class _Dark {
  static const Color primary = Color(0xFF6E90E0);
  static const Color primaryDark = Color(0xFF3F5FA8);
  static const Color primaryLight = Color(0xFF9DBEF2);

  static const Color accent = Color(0xFFF5B85A);
  static const Color accentDark = Color(0xFFE0A030);

  static const Color success = Color(0xFF4CC98A);
  static const Color successBg = Color(0xFF163527);

  static const Color warning = Color(0xFFE8BE5C);
  static const Color warningBg = Color(0xFF3A2E12);

  static const Color danger = Color(0xFFEF6B6B);
  static const Color dangerBg = Color(0xFF3A1E1E);

  static const Color info = Color(0xFF63A6EA);
  static const Color infoBg = Color(0xFF17293D);

  // Same validated ordinal ramp, re-stepped and re-checked against the dark
  // surface (#161B29) rather than flipped from the light-mode values.
  static const Color statusSubmitted = Color(0xFF9DBEF2);
  static const Color statusSubmittedBg = Color(0xFF1E3352);
  static const Color statusVerifying = Color(0xFF6E93DD);
  static const Color statusVerifyingBg = Color(0xFF1B3050);
  static const Color statusReviewing = Color(0xFF3F5FA8);
  static const Color statusReviewingBg = Color(0xFF202D4D);

  static const Color neutralBg = Color(0xFF0F1320);
  static const Color surface = Color(0xFF161B29);
  static const Color border = Color(0xFF2A3244);

  static const Color textPrimary = Color(0xFFF3F5FA);
  static const Color textSecondary = Color(0xFFB7BECF);
  static const Color textMuted = Color(0xFF7E8AA3);

  static const Color cardShadow = Color(0x40000000);

  // Glassmorphism: a translucent lift off the dark surface color, with a
  // faint light edge highlight rather than a dark border (reads as "glass"
  // instead of just "a slightly different dark box").
  static const Color glassSurface = Color(0xB3161B29);
  static const Color glassSurfaceStrong = Color(0xE0161B29);
  static const Color glassBorder = Color(0x26FFFFFF);
}

/// Centralized color palette for Baliwag EduConnect.
/// Call [AppColors.setDark] once per theme change (done in main.dart) so
/// every widget reading these getters reflects the active mode.
class AppColors {
  AppColors._();

  static bool _dark = false;
  static void setDark(bool value) => _dark = value;
  static bool get isDark => _dark;

  static Color get primary => _dark ? _Dark.primary : _Light.primary;
  static Color get primaryDark =>
      _dark ? _Dark.primaryDark : _Light.primaryDark;
  static Color get primaryLight =>
      _dark ? _Dark.primaryLight : _Light.primaryLight;

  static Color get accent => _dark ? _Dark.accent : _Light.accent;
  static Color get accentDark => _dark ? _Dark.accentDark : _Light.accentDark;

  static Color get success => _dark ? _Dark.success : _Light.success;
  static Color get successBg => _dark ? _Dark.successBg : _Light.successBg;

  static Color get warning => _dark ? _Dark.warning : _Light.warning;
  static Color get warningBg => _dark ? _Dark.warningBg : _Light.warningBg;

  static Color get danger => _dark ? _Dark.danger : _Light.danger;
  static Color get dangerBg => _dark ? _Dark.dangerBg : _Light.dangerBg;

  static Color get info => _dark ? _Dark.info : _Light.info;
  static Color get infoBg => _dark ? _Dark.infoBg : _Light.infoBg;

  static Color get statusSubmitted =>
      _dark ? _Dark.statusSubmitted : _Light.statusSubmitted;
  static Color get statusSubmittedBg =>
      _dark ? _Dark.statusSubmittedBg : _Light.statusSubmittedBg;
  static Color get statusVerifying =>
      _dark ? _Dark.statusVerifying : _Light.statusVerifying;
  static Color get statusVerifyingBg =>
      _dark ? _Dark.statusVerifyingBg : _Light.statusVerifyingBg;
  static Color get statusReviewing =>
      _dark ? _Dark.statusReviewing : _Light.statusReviewing;
  static Color get statusReviewingBg =>
      _dark ? _Dark.statusReviewingBg : _Light.statusReviewingBg;

  static Color get neutralBg => _dark ? _Dark.neutralBg : _Light.neutralBg;
  static Color get surface => _dark ? _Dark.surface : _Light.surface;
  static Color get border => _dark ? _Dark.border : _Light.border;

  static Color get textPrimary =>
      _dark ? _Dark.textPrimary : _Light.textPrimary;
  static Color get textSecondary =>
      _dark ? _Dark.textSecondary : _Light.textSecondary;
  static Color get textMuted => _dark ? _Dark.textMuted : _Light.textMuted;

  static List<Color> get heroGradient => _dark
      ? [_Dark.primaryDark, _Dark.primary, _Dark.primaryLight]
      : [_Light.primary, const Color(0xFF2648A8), _Light.primaryLight];
  static List<Color> get accentGradient => [accent, accentDark];

  static Color get cardShadow => _dark ? _Dark.cardShadow : _Light.cardShadow;

  static Color get glassSurface =>
      _dark ? _Dark.glassSurface : _Light.glassSurface;
  static Color get glassSurfaceStrong =>
      _dark ? _Dark.glassSurfaceStrong : _Light.glassSurfaceStrong;
  static Color get glassBorder =>
      _dark ? _Dark.glassBorder : _Light.glassBorder;

  /// Ambient ordered pair of glow colors (used behind glass panels as soft,
  /// blurred color blobs) — primary hue + accent hue, tuned per mode.
  static List<Color> get glowColors => [primary, accent];

  /// Assembles the current mode's values into the [ThemeExtension] consumed
  /// via `Theme.of(context)` (see app_theme_context.dart) — read exactly
  /// like every other getter above, so it must be built only after
  /// [setDark] has been called for the mode being themed (same rule
  /// AppTheme's own builder already follows).
  static AppSemanticColors get semantic => AppSemanticColors(
    success: success,
    successBg: successBg,
    warning: warning,
    warningBg: warningBg,
    dangerBg: dangerBg,
    info: info,
    infoBg: infoBg,
    statusSubmitted: statusSubmitted,
    statusSubmittedBg: statusSubmittedBg,
    statusVerifying: statusVerifying,
    statusVerifyingBg: statusVerifyingBg,
    statusReviewing: statusReviewing,
    statusReviewingBg: statusReviewingBg,
    neutralBg: neutralBg,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textMuted: textMuted,
    border: border,
    cardShadow: cardShadow,
    glassSurface: glassSurface,
    glassSurfaceStrong: glassSurfaceStrong,
    glassBorder: glassBorder,
    primaryDark: primaryDark,
    primaryLight: primaryLight,
    accentDark: accentDark,
    heroGradient: heroGradient,
    accentGradient: accentGradient,
    glowColors: glowColors,
  );
}
