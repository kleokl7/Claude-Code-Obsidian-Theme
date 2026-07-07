# Scroll map marker redesign — starburst + circles

**Date:** 2026-07-07
**Scope:** `theme.css` only (section 10, `.cc-scroll-map` rules). No companion-plugin JS changes — the plugin renders positioned divs; all cosmetics are CSS.

## Goal

Replace the "terminal block" rounded-square markers with shapes that match the
theme's brand: the Claude starburst for H1 landmarks, soft circles for H2/H3.
Approved visually by Kleanthi (widget mockups, 2026-07-07).

## Design

### Shapes
- **H1**: Claude starburst — an 11-ray spark drawn as an inline SVG data-URI
  applied with CSS `mask` to the marker's `::before`. The marker element itself
  becomes a plain note-background disc (`border-radius: 50%`), slightly larger
  than the spark — that disc is what punches the gap in the progress line
  (masks clip `box-shadow`, so the halo trick can't work on H1).
  Base 16px disc / 12px spark (`inset: 2px`); strip-hover 20px / 16px.
- **H2**: circle, 7px base, 9px on strip hover.
- **H3**: circle, 6px base, 8px on strip hover.
- Strip-hover growth is uniform (no more tall-rectangle stretch — circles
  can't go oval). The fisheye magnification (`--cc-mag`) is unchanged.

### Colors
- **Filled ("read") markers are full coral at every level**: `--cc-accent`
  (`#c15f3c` light / `#d97757` dark). The old `--cc-map-h2` / `--cc-map-h3`
  muted mixes are deleted; hierarchy comes from size + the H1 spark shape.
- **Faded ("unread") markers**: the same coral mixed **45%** toward the note
  background — `color-mix(in srgb, var(--cc-accent) 45%, var(--cc-bg))`.
  Opaque on purpose: the progress line must never show through a marker.
- No more hollow/outline state; borders are removed entirely.

### Line gap (key requirement)
The progress line never touches a marker in any state (filled, faded,
hovered). Circles get a `box-shadow: 0 0 0 2px var(--cc-bg)` halo ring;
H1 gets it from its background disc. Both are opaque `--cc-bg`.

### Behavior kept as-is
- Fade→fill on scroll: the existing `cc-scroll-dot-pass` keyframe animating
  `background` on the note's scroll timeline, with per-marker
  `animation-range` from `--cc-dot-frac`. For H1 the animation moves to
  `::before` (the sparkle layer); the element itself gets `animation: none`.
- Hover highlight (`--cc-accent-bright`) + tooltip `::after`. The bright
  hover background targets `:not([data-level="1"])` elements and
  `[data-level="1"]::before`, so the H1 knockout disc never turns coral.
- Reduced-motion carve-out must also cover `.cc-scroll-dot::before`, or the
  global 0.01ms override pins the H1 fill at 100%.
- Mobile stays hidden; plugin band fallback unchanged.
