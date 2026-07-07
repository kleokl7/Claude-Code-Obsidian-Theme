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
- **Faded ("unread") markers**: the same coral at **45% opacity** over the
  marker's opaque note-bg disc — visually identical to a 45% mix toward the
  background, and the disc stays opaque so the progress line never shows
  through a marker. (First cut animated a `color-mix()` background to a hex;
  Chromium's scroll-driven color interpolation miscomputed it to neon
  yellow — `oklab(1 95 60)`, the raw sRGB channels unconverted. Animating
  `opacity` on a full-coral `::before` layer is numeric and immune.)
- No more hollow/outline state; borders are removed entirely.

### Line gap (key requirement)
The progress line never touches a marker in any state (filled, faded,
hovered). Circles get a `box-shadow: 0 0 0 2px var(--cc-bg)` halo ring;
H1 gets it from its background disc. Both are opaque `--cc-bg`.

### Behavior kept as-is
- Fade→fill on scroll: the `cc-scroll-dot-pass` keyframe (now `to {opacity: 1}`)
  runs on every marker's `::before` color layer, on the note's scroll
  timeline with per-marker `animation-range` from `--cc-dot-frac`.
- Hover highlight (`--cc-accent-bright`) + tooltip `::after`. The bright
  hover background targets `::before` on all levels, so the knockout discs
  never turn coral.
- Per-level `border-radius`/`background` must stay explicit on the
  `[data-level="1"]`/`[data-level="3"]` theme rules — the plugin's baseline
  level selectors outrank the theme's base rule (this is why the old code
  had those "explicit: outranks baseline" declarations).

## Mobile (added same day, approved via second mockup)

Markers now show on mobile too, riding the theme's bottom progress bar,
**cut in half** and **visual only** (Kleanthi's call: no tap-to-jump).

- Plugin: the `Platform.isMobile` early-return in `onload()` is gone;
  instead the hover/fisheye listeners and the dot click handler are
  desktop-only. Baseline `styles.css` still hides the map on mobile —
  themes must opt in.
- Theme: `body.cc-scroll-progress.is-mobile .cc-scroll-map` bottom-docks
  the map (`height: 14px; overflow: hidden`) so every marker is sliced at
  the screen edge; dots get `top: 100%` (equator on the clip edge — a true
  half) and `pointer-events: none`. All heading levels render (variant A);
  the plugin's `MIN_GAP_PX` clustering handles phone-width density
  (42 headings → 24 markers at 380pt). Mobile sizes run slightly larger
  (9/20/7px) since only the top half shows.
- The mobile bar's `::before` grew into an 18px upward-fading band (like
  desktop's) so note text dissolves before it reaches the marker tips;
  the 4px track paints at the band's bottom edge.
- Without the scroll-progress toggle there is no bar, so the map stays
  hidden on mobile.
- Reduced-motion carve-out must also cover `.cc-scroll-dot::before`, or the
  global 0.01ms override pins the H1 fill at 100%.
- Mobile stays hidden; plugin band fallback unchanged.
