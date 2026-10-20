import 'package:flutter/material.dart';

/// Lays out a row of [StatCard]s (or similar fixed-content cards) so they
/// never overflow — the column count is derived from the *actual* available
/// width at build time (via [LayoutBuilder]), not a static mobile/desktop
/// flag. A hardcoded column count for "wide" screens breaks at in-between
/// widths (e.g. just past the desktop breakpoint, before a side rail has
/// left enough room for that many cards side by side): each card gets
/// squeezed narrower than its own fixed-size content (an icon box, in
/// StatCard's case), which overflows for real, not just cosmetically.
/// Wrapping to another row instead — the same thing text does with
/// [TextOverflow.ellipsis] — is always safe regardless of exactly how
/// narrow the available space gets.
class StatCardRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double minCardWidth;

  /// Caps how wide each card grows on wide screens with few children (e.g.
  /// a 2-card row would otherwise stretch to half the page width). Leave
  /// null to keep the previous fill-the-row behavior — used by rows with
  /// enough cards that stretching isn't visually odd.
  final double? maxCardWidth;

  const StatCardRow({
    super.key,
    required this.children,
    this.spacing = 14,
    this.minCardWidth = 150,
    this.maxCardWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / (minCardWidth + spacing))
            .floor()
            .clamp(1, children.length);
        var cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        if (maxCardWidth != null && cardWidth > maxCardWidth!) {
          cardWidth = maxCardWidth!;
        }
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}
