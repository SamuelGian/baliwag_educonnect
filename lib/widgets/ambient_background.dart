import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_context.dart';

/// Soft, glowing color blobs (cheap radial gradients, no real blur needed)
/// behind a base surface color — the "glow behind the glass" backdrop that
/// [GlassPanel] content sits on top of. Purely decorative; ignores pointer
/// events so it never intercepts taps meant for the content above it.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final glows = context.appColors.glowColors;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: context.appColors.neutralBg),
        Positioned(
          top: -120,
          right: -100,
          child: _Blob(
            color: glows[0],
            size: 380,
            alpha: AppColors.isDark ? 0.32 : 0.22,
          ),
        ),
        Positioned(
          bottom: -140,
          left: -120,
          child: _Blob(
            color: glows[1],
            size: 420,
            alpha: AppColors.isDark ? 0.24 : 0.18,
          ),
        ),
        Positioned(
          top: 220,
          left: -80,
          child: _Blob(
            color: glows[0],
            size: 260,
            alpha: AppColors.isDark ? 0.16 : 0.12,
          ),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  final double alpha;

  const _Blob({required this.color, required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
