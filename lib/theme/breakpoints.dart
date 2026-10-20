/// Below this width: mobile layout (floating bottom nav, vertical card
/// lists). At or above it: desktop/web layout (collapsible side rail, data
/// tables/grids). Single source of truth so every screen switches at the
/// same point instead of each hardcoding its own threshold.
const double kDesktopBreakpoint = 600;

/// Below this total window width, the desktop side rail auto-collapses to
/// an icon-only "mini" rail (see [kMiniSidebarWidth]) instead of its full
/// labeled [kSidebarWidth] — a fixed 240px sidebar plus content leaves too
/// little room for the content itself between 600-840px, which is exactly
/// what caused card text to get squeezed down to ellipsis in the first
/// place. Chosen as sidebar + a reasonable minimum comfortable content
/// width (240 + 600).
const double kFullSidebarMinWidth = 840;

const double kSidebarWidth = 240;
const double kMiniSidebarWidth = 72;
