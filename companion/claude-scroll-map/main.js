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
 */

const { Plugin, MarkdownView, Platform, debounce } = require('obsidian');

const MAX_LEVEL = 3;      // render dots for H1–H3
const MIN_GAP_PX = 11;    // guaranteed pixel gap between markers
const FISHEYE_RANGE = 70;  // px radius of dock-style magnification
const FISHEYE_BOOST = 0.45; // max extra scale at cursor

module.exports = class ClaudeScrollMap extends Plugin {
  onload() {
    // Mobile stays progress-bar-only (the theme's CSS bar): a phone-width
    // strip can't fit heading dots legibly, and there's no hover anyway.
    if (Platform.isMobile) return;
    this.refresh = debounce(() => this.updateAll(), 250, true);
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
      map.addEventListener('mousemove', (e) => this.onStripHover(map, e));
      map.addEventListener('mouseleave', () => this.clearHover(map));
    }
    map.empty();

    // Fractions along the bar. In the editor, CodeMirror gives real pixel
    // offsets (matches the CSS fill exactly); in reading mode fall back to
    // character-offset ratio — close enough for a strip map.
    const cm =
      view.getMode() !== 'preview' && view.editor && view.editor.cm
        ? view.editor.cm
        : null;
    const docLen = Math.max(1, view.editor ? view.editor.getValue().length : 1);
    let denomPx = 1;
    if (cm) {
      const s = cm.scrollDOM;
      denomPx = Math.max(1, s.scrollHeight - s.clientHeight);
    }

    const pts = [];
    for (const h of headings) {
      let frac;
      if (cm) {
        try {
          const pos = Math.min(h.position.start.offset, cm.state.doc.length - 1);
          frac = cm.lineBlockAt(Math.max(0, pos)).top / denomPx;
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
      // scroll fraction at which the progress fill reaches this marker —
      // the theme's hollow→solid animation keys off it (clamped so
      // end-of-note markers still trigger)
      dot.style.setProperty('--cc-dot-frac', Math.min(frac, 0.995).toFixed(4));
      dot.addEventListener('click', (evt) => {
        evt.preventDefault();
        view.setEphemeralState({ line: h.position.start.line });
      });
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
