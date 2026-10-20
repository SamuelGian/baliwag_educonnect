import 'package:flutter/material.dart';
import 'app_semantic_colors.dart';

/// `Theme.of(context)`-backed shorthands: `context.scheme` for the roles
/// Material's [ColorScheme] already covers (primary, secondary, surface,
/// error), `context.appColors` for everything else this design system needs
/// that [ColorScheme] has no role for (success, status-progression steps,
/// glass surfaces, etc. — see [AppSemanticColors]).
extension AppThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
