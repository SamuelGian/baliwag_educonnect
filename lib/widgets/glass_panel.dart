import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme_context.dart';

/// A frosted-glass panel: real backdrop blur + a translucent tint + a faint
/// light edge highlight, so content behind it (an [AmbientBackground], a
/// gradient hero, another panel) shows through softly instead of being
/// fully hidden. Use in place of a plain [Container] wherever the
/// glassmorphism treatment applies.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final bool strong;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 18,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: strong
                ? context.appColors.glassSurfaceStrong
                : context.appColors.glassSurface,
            borderRadius: borderRadius,
            border: Border.all(
              color: context.appColors.glassBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: context.appColors.cardShadow,
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
