import 'package:flutter/material.dart';

/// Semantic color tokens beyond what [ColorScheme] has roles for (success,
/// status-progression steps, glassmorphism surfaces, etc.) — registered as a
/// [ThemeExtension] so they're reachable the same way as the rest of the
/// theme, via `Theme.of(context).extension<AppSemanticColors>()` (or the
/// `context.appColors` shorthand in app_theme_context.dart), instead of a
/// separate global static lookup.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color dangerBg;
  final Color info;
  final Color infoBg;

  final Color statusSubmitted;
  final Color statusSubmittedBg;
  final Color statusVerifying;
  final Color statusVerifyingBg;
  final Color statusReviewing;
  final Color statusReviewingBg;

  final Color neutralBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color cardShadow;

  final Color glassSurface;
  final Color glassSurfaceStrong;
  final Color glassBorder;

  final Color primaryDark;
  final Color primaryLight;
  final Color accentDark;

  final List<Color> heroGradient;
  final List<Color> accentGradient;
  final List<Color> glowColors;

  const AppSemanticColors({
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.dangerBg,
    required this.info,
    required this.infoBg,
    required this.statusSubmitted,
    required this.statusSubmittedBg,
    required this.statusVerifying,
    required this.statusVerifyingBg,
    required this.statusReviewing,
    required this.statusReviewingBg,
    required this.neutralBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.cardShadow,
    required this.glassSurface,
    required this.glassSurfaceStrong,
    required this.glassBorder,
    required this.primaryDark,
    required this.primaryLight,
    required this.accentDark,
    required this.heroGradient,
    required this.accentGradient,
    required this.glowColors,
  });

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
    Color? dangerBg,
    Color? info,
    Color? infoBg,
    Color? statusSubmitted,
    Color? statusSubmittedBg,
    Color? statusVerifying,
    Color? statusVerifyingBg,
    Color? statusReviewing,
    Color? statusReviewingBg,
    Color? neutralBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? cardShadow,
    Color? glassSurface,
    Color? glassSurfaceStrong,
    Color? glassBorder,
    Color? primaryDark,
    Color? primaryLight,
    Color? accentDark,
    List<Color>? heroGradient,
    List<Color>? accentGradient,
    List<Color>? glowColors,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      dangerBg: dangerBg ?? this.dangerBg,
      info: info ?? this.info,
      infoBg: infoBg ?? this.infoBg,
      statusSubmitted: statusSubmitted ?? this.statusSubmitted,
      statusSubmittedBg: statusSubmittedBg ?? this.statusSubmittedBg,
      statusVerifying: statusVerifying ?? this.statusVerifying,
      statusVerifyingBg: statusVerifyingBg ?? this.statusVerifyingBg,
      statusReviewing: statusReviewing ?? this.statusReviewing,
      statusReviewingBg: statusReviewingBg ?? this.statusReviewingBg,
      neutralBg: neutralBg ?? this.neutralBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      cardShadow: cardShadow ?? this.cardShadow,
      glassSurface: glassSurface ?? this.glassSurface,
      glassSurfaceStrong: glassSurfaceStrong ?? this.glassSurfaceStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      accentDark: accentDark ?? this.accentDark,
      heroGradient: heroGradient ?? this.heroGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      glowColors: glowColors ?? this.glowColors,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> gList(List<Color> a, List<Color> b) =>
        t < 0.5 ? a : b; // gradients switch rather than blend per-stop
    return AppSemanticColors(
      success: c(success, other.success),
      successBg: c(successBg, other.successBg),
      warning: c(warning, other.warning),
      warningBg: c(warningBg, other.warningBg),
      dangerBg: c(dangerBg, other.dangerBg),
      info: c(info, other.info),
      infoBg: c(infoBg, other.infoBg),
      statusSubmitted: c(statusSubmitted, other.statusSubmitted),
      statusSubmittedBg: c(statusSubmittedBg, other.statusSubmittedBg),
      statusVerifying: c(statusVerifying, other.statusVerifying),
      statusVerifyingBg: c(statusVerifyingBg, other.statusVerifyingBg),
      statusReviewing: c(statusReviewing, other.statusReviewing),
      statusReviewingBg: c(statusReviewingBg, other.statusReviewingBg),
      neutralBg: c(neutralBg, other.neutralBg),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      border: c(border, other.border),
      cardShadow: c(cardShadow, other.cardShadow),
      glassSurface: c(glassSurface, other.glassSurface),
      glassSurfaceStrong: c(glassSurfaceStrong, other.glassSurfaceStrong),
      glassBorder: c(glassBorder, other.glassBorder),
      primaryDark: c(primaryDark, other.primaryDark),
      primaryLight: c(primaryLight, other.primaryLight),
      accentDark: c(accentDark, other.accentDark),
      heroGradient: gList(heroGradient, other.heroGradient),
      accentGradient: gList(accentGradient, other.accentGradient),
      glowColors: gList(glowColors, other.glowColors),
    );
  }
}
