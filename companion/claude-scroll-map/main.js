'use strict';

/* Claude Scroll Map — companion plugin to the Claude Code theme.
 *
 * Renders a strip of clickable heading dots (.cc-scroll-map) into every
 * markdown view, positioned by scroll progress. The theme's scroll
 * progress bar (pure CSS, scroll-driven animation) draws the track and
 * fill; this plugin only owns the dots and their hover behavior.
 *
 * - Dot size by heading level (H1 > H2 > H3) — via CSS [data-level]
 * - Hover a dot → heading name tooltip (CSS attr(data-label))
 * - Hover the bare strip → tooltip of the nearest heading dot to the left
 * - Click / tap a dot → jump to that heading (works in both modes)
 * - Dots that would visually overlap are merged (higher level wins)
 * - Mobile: markers render too (the theme docks them on its bottom
 *   progress bar, cut at the middle) but are VISUAL ONLY — no hover,
 *   no fisheye, no tap-to-jump; the theme also sets pointer-events:none
 */

const { Plugin, MarkdownView, Platform, debounce } = require('obsidian');

const MAX_LEVEL = 3;      // render dots for H1–H3
const MIN_GAP_PX = 11;    // guaranteed pixel gap between markers
const FISHEYE_RANGE = 70;  // px radius of dock-style magnification
const FISHEYE_BOOST = 0.45; // max extra scale at cursor

module.exports = class ClaudeScrollMap extends Plugin {
  onload() {
    this.refresh = debounce(() => this.updateAll(), 250, true);
    // Folding/unfolding a heading fires none of the workspace events below,
    // yet it changes the scroller's geometry — so the marker fractions
    // (--cc-dot-frac, keyed off the scroll range) silently go stale and the
    // dots stop filling as the progress line passes them. A ResizeObserver
    // on each note's content box catches exactly those height changes (fold,
    // edit, reflow) and recomputes. WeakSet guards against re-observing the
    // same element (the observe() self-fire would otherwise loop via refresh).
    this.geoObserver = new ResizeObserver(() => this.refresh());
    this.register(() => this.geoObserver.disconnect());
    this.observed = new WeakSet();
    this.registerEvent(this.app.workspace.on('layout-change', this.refresh));
    this.registerEvent(this.app.workspace.on('active-leaf-change', this.refresh));
    this.registerEvent(this.app.workspace.on('file-open', this.refresh));
    this.registerEvent(this.app.workspace.on('resize', this.refresh));
    this.registerEvent(this.app.metadataCache.on('changed', this.refresh));
    this.app.workspace.onLayoutReady(() => this.updateAll());
  }

  onunload() {
    document.querySelectorAll('.cc-scroll-map').forEach((el) => el.remove());
  }

  updateAll() {
    this.app.workspace.iterateAllLeaves((leaf) => {
      if (leaf.view instanceof MarkdownView) this.updateView(leaf.view);
    });
  }

  updateView(view) {
    const content = view.containerEl.querySelector('.view-content');
    if (!content) return;
    let map = content.querySelector(':scope > .cc-scroll-map');

    const file = view.file;
    const cache = file && this.app.metadataCache.getFileCache(file);
    const headings = ((cache && cache.headings) || []).filter(
      (h) => h.level <= MAX_LEVEL
    );
    if (!file || headings.length === 0) {
      if (map) map.remove();
      return;
    }

    if (!map) {
      map = content.createDiv({ cls: 'cc-scroll-map' });
      if (!Platform.isMobile) {
        map.addEventListener('mousemove', (e) => this.onStripHover(map, e));
        map.addEventListener('mouseleave', () => this.clearHover(map));
      }
    }
    map.empty();

    // Fractions along the bar. In the editor, CodeMirror gives real pixel
    // offsets (matches the CSS fill exactly); in reading mode fall back to
    // character-offset ratio — close enough for a strip map.
    let cm =
      view.getMode() !== 'preview' && view.editor && view.editor.cm
        ? view.editor.cm
        : null;
    const docLen = Math.max(1, view.editor ? view.editor.getValue().length : 1);
    let denomPx = 1;
    let denomDoc = 1;
    if (cm) {
      const s = cm.scrollDOM;
      denomPx = s.scrollHeight - s.clientHeight;
      denomDoc = Math.max(1, s.scrollHeight);
      // A note that fits without scrolling has no scroll range to map the
      // fill onto — fall back to char-offset fractions, same as reading
      // mode.
      if (denomPx <= 0) cm = null;
    }

    // Watch the box whose height tracks the scroll range, so a fold/unfold
    // (which fires no workspace event) triggers a recompute. In the editor
    // that's the CodeMirror content; in reading mode, the preview sizer.
    const geoEl = cm
      ? cm.contentDOM
      : content.querySelector('.markdown-preview-sizer');
    if (geoEl && !this.observed.has(geoEl)) {
      this.observed.add(geoEl);
      this.geoObserver.observe(geoEl);
    }

    const pts = [];
    for (const h of headings) {
      let frac;
      if (cm) {
        try {
          const pos = Math.min(h.position.start.offset, cm.state.doc.length - 1);
          const top = cm.lineBlockAt(Math.max(0, pos)).top;
          // Position AND fill trigger are the same value: the marker's
          // fraction of the DOCUMENT height (a true minimap). The progress
          // fill is a full-width bar scaled by scroll progress, so its
          // leading edge sits at x = progress. A marker drawn at x = frac
          // must therefore fill exactly when progress reaches frac — using
          // the scroll RANGE (top/denomPx) instead makes the trigger drift
          // ahead of the marker, so the line visibly sweeps past still-faded
          // dots (badly so when the note barely scrolls, e.g. folded).
          frac = top / denomDoc;
        } catch (_) {
          frac = h.position.start.offset / docLen;
        }
      } else {
        frac = h.position.start.offset / docLen;
      }
      pts.push({ h, frac: Math.max(0, Math.min(1, frac)) });
    }

    // Cluster markers that would sit closer than MIN_GAP_PX at the pane's
    // real width; each cluster is represented by its most important
    // heading (lowest level wins, earliest breaks ties).
    const width = map.clientWidth || content.clientWidth || 800;
    const minFrac = MIN_GAP_PX / Math.max(1, width);
    const kept = [];
    let cluster = [];
    const flush = () => {
      if (!cluster.length) return;
      let best = cluster[0];
      for (const c of cluster) if (c.h.level < best.h.level) best = c;
      kept.push(best);
      cluster = [];
    };
    for (const c of pts) {
      if (!cluster.length || c.frac - cluster[0].frac < minFrac) cluster.push(c);
      else { flush(); cluster.push(c); }
    }
    flush();

    for (const { h, frac } of kept) {
      const dot = map.createEl('button', { cls: 'cc-scroll-dot' });
      dot.dataset.level = String(h.level);
      // data-label only — an aria-label would also trigger Obsidian's
      // native black tooltip on top of the styled one
      dot.dataset.label = h.heading;
      dot.style.left = (frac * 100).toFixed(2) + '%';
      // The fill animation keys off the marker's own position, so the dot
      // turns coral the instant the progress line's leading edge reaches it
      // (clamped so a marker sitting at the very end still triggers).
      dot.style.setProperty('--cc-dot-frac', Math.min(frac, 0.995).toFixed(4));
      if (!Platform.isMobile) {
        dot.addEventListener('click', (evt) => {
          evt.preventDefault();
          view.setEphemeralState({ line: h.position.start.line });
        });
      }
    }
  }

  // Hovering the bare strip: dock-style fisheye magnification around the
  // cursor, plus a tooltip on the nearest dot to the left — "the section
  // you are inside at this bar position".
  onStripHover(map, e) {
    const rect = map.getBoundingClientRect();
    const px = e.clientX - rect.left;
    const x = px / Math.max(1, rect.width);
    let best = null;
    let bestLeft = -1;
    for (const dot of map.querySelectorAll('.cc-scroll-dot')) {
      const left = parseFloat(dot.style.left) / 100;
      const d = Math.abs(left * rect.width - px);
      const s = 1 + FISHEYE_BOOST * Math.max(0, 1 - d / FISHEYE_RANGE);
      dot.style.setProperty('--cc-mag', s.toFixed(3));
      if (left <= x && left > bestLeft) {
        best = dot;
        bestLeft = left;
      }
    }
    // Pointer directly on a marker: trust it — otherwise its :hover
    // tooltip and the nearest-left .cc-hovered tooltip both show.
    const direct =
      e.target instanceof HTMLElement && e.target.closest('.cc-scroll-dot');
    if (direct) best = direct;
    map
      .querySelectorAll('.cc-hovered')
      .forEach((d) => d.classList.remove('cc-hovered'));
    if (best) best.classList.add('cc-hovered');
    // Drives the theme's line-thickening. A toggled class is cheaper than
    // the CSS :has(:hover) it replaces (no per-pointer-move recalc).
    if (map.parentElement) map.parentElement.classList.add('cc-map-hover');
  }

  clearHover(map) {
    map.querySelectorAll('.cc-scroll-dot').forEach((d) => {
      d.classList.remove('cc-hovered');
      d.style.removeProperty('--cc-mag');
    });
    if (map.parentElement) map.parentElement.classList.remove('cc-map-hover');
  }
};
