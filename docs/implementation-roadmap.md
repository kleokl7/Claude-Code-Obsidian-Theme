# Implementation roadmap — future work

Specs for work that is **deliberately not implemented yet**. Each item was
scoped during the July 2026 design review so it can be picked up later
without re-research. Nothing here should be started without owner approval.

Already shipped from that review (July 2026): naming sweep to Claude Code
Orange, light-mode tuning dials, accent-aware forwarded-task chevron, table
color parity via Obsidian's `--table-*` variables, companion install script,
`versions.json` + release-script guard, fonts/trademark/scroll-support docs.

Shipped in the September 2026 pass (1.5.0): sticky-headings breadcrumb
integration removed entirely (plugin no longer in use; its header-gutter
item is gone from this roadmap), palette blocks consolidated into one shared
mapping, metric-matched font fallbacks, shared motion token, focus rings,
unresolved-link and focused-pane cues, reading-view task states fixed for
the Tasks plugin DOM, TOC comment at the top of `theme.css`.

---

## 1. Coverage gaps — styling recipes

The owner doesn't use these surfaces today. If the theme's audience grows,
these are the recipes. Common rule: reuse existing tokens (`--cc-bg*`,
`--cc-table-*`, `--cc-border*`, `--interactive-accent`) — never invent a
parallel palette.

### Obsidian Bases

| Element | Treatment |
| --- | --- |
| View chrome / toolbar | `--cc-bg-alt`, border `--cc-border`, radius `--radius-m` |
| Table/grid cells | reuse `--cc-table-bg` / `--cc-table-header` / `--cc-table-border` |
| Selected row/cell | `--cc-selection` |
| Primary buttons | `--interactive-accent` + `--text-on-accent` |
| Cards layout | card bg `--cc-bg`, soft border, radius `--cc-radius` |

Scope under the Bases leaf type (confirm the live `data-type` string before
writing selectors). Done when opening a Base doesn't feel like leaving the
theme.

### Canvas

Canvas bg slightly deeper than `--cc-bg` (or subtle dot grid in
`--cc-border-soft`); card fill `--cc-bg`/`--cc-bg-alt`; card border
`--cc-border`, selected `--interactive-accent`; group frames faint coral mix
with large radius; edges `--graph-line`, active edge coral; menus styled like
the command palette cards.

### PDF view

Toolbar/background `--cc-bg-alt`; warm (not cold black) page shadow; coral
find-highlight. **Never recolor the PDF page content itself.**

### Hover popovers / tooltips / suggestion menus

`--cc-bg-alt` surface, `--cc-border`, `--cc-radius`, warm soft shadow. The
preview markdown inside inherits note styling once the surface is themed.

### Notices / toasts / modals

Modal surface `--cc-bg`/`--cc-bg-alt` + `--cc-radius` + `--cc-border`; CTAs
already covered by `button.mod-cta`; notices optionally get a coral left
border.

### Math (KaTeX / MathJax)

`.math` foreground `var(--cc-text)`; display math gets its own vertical
margin (~`1em 0`) independent of the tight `--p-spacing`; don't restyle TeX
internals beyond foreground color.

### Mermaid

Prefer variables Mermaid reads if Obsidian exposes them; else node fill
`--cc-bg-deep`/`--cc-bg-alt`, stroke `--cc-border` (coral for emphasis),
edges `--graph-line`, text `--cc-text`. Needs explicit `.theme-light` and
`.theme-dark` sets.

### Tables inside callouts (known niche gap)

Stock Obsidian re-declares `--table-border-color` on `.callout` with a
callout-tinted mix, which outranks the theme's body-level mapping — so a
table nested in a callout draws callout-tinted outer/widget borders against
the theme's warm cell grid (pre-existing behavior, unchanged by the 2026-07
table work). If it ever matters: re-map the variable on `.callout` too, at
the cost of stock's callout-tinting design.

### Popular plugins (only if audience demands)

| Plugin | Direction |
| --- | --- |
| Calendar | day cells `--cc-bg-alt`; today = coral ring/fill; note dots in accent |
| Kanban | lane `--cc-bg-alt`, card `--cc-bg`, pills reuse tag styles |
| Dataview | tables reuse `--cc-table-*`; task queries inherit checkbox styles if the DOM matches |
| Excalidraw | theme the canvas background only; don't fight its own theme engine |

### Print / export

`@media print`: force light paper tokens, black text, underlined links, hide
app chrome. Publish sites use different CSS entry points — separate effort.

---

## 2. CSS maintainability

`theme.css` is ~1650 lines, with a TOC comment at the top matching the
section banners (done 2026-09). In order of value:

1. **Strict section discipline** — plugin hacks never land inside token
   blocks; new plugin work goes in section 9+.
2. **Multi-file `src/` + concat build** — only when a second maintainer
   exists or the file passes ~2.5–3k lines. Obsidian still ships one
   `theme.css`; `build.sh` concatenates.
3. **Reduce `!important` on links** only if a real conflict appears (19
   left after the 2026-09 pass, down from 35).
4. **Keep documenting selector contracts** for fragile integrations
   (scroll-map classes, Tasks-plugin task DOM, `--table-*` mapping pinned
   to the Obsidian version it was inspected against).

---

## 3. Community listing quality

Present: `manifest.json`, `theme.css`, `versions.json` (+ release guard),
`release.sh`, README screenshots, MIT license.

Remaining when distribution becomes a priority:

| Item | Action |
| --- | --- |
| Chrome screenshots | add `screenshots/chrome-light.png` / `chrome-dark.png` showing sidebar + tabs, not just the note body |
| `theme-preview.png` | regenerate after any visual change; it's the storefront |
| Release notes | always pass real `--notes` to `release.sh` |
| Issue template | OS, Obsidian version, light/dark, Style Settings on/off, plugins |
| README badges | latest release + min app version (optional) |
| Community plugin store | submit Claude Scroll Map only if manual/script install proves insufficient |

The release procedure itself lives in README → *Releasing (maintainers)*
(release.sh enforces the guards). Roadmap-only additions: update README when
user-facing options change, and spot-check installing from the release
download rather than the working copy.
