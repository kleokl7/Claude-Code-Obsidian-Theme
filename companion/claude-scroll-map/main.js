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
const MIN_GAP = 0.008;    // merge dots closer than 0.8% of the bar

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

    let lastFrac = -1;
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
      frac = Math.max(0, Math.min(1, frac));
      if (frac - lastFrac < MIN_GAP) continue; // merge overlapping dots
      lastFrac = frac;

      const dot = map.createEl('button', { cls: 'cc-scroll-dot' });
      dot.dataset.level = String(h.level);
      dot.dataset.label = h.heading;
      dot.setAttribute('aria-label', h.heading);
      dot.style.left = (frac * 100).toFixed(2) + '%';
      dot.addEventListener('click', (evt) => {
        evt.preventDefault();
        view.setEphemeralState({ line: h.position.start.line });
      });
    }
  }

  // Hovering the bare strip lights up the nearest dot to the left, which
  // shows its tooltip — "the section you are inside at this bar position".
  onStripHover(map, e) {
    const rect = map.getBoundingClientRect();
    const x = (e.clientX - rect.left) / Math.max(1, rect.width);
    let best = null;
    let bestLeft = -1;
    for (const dot of map.querySelectorAll('.cc-scroll-dot')) {
      const left = parseFloat(dot.style.left) / 100;
      if (left <= x && left > bestLeft) {
        best = dot;
        bestLeft = left;
      }
    }
    this.clearHover(map);
    if (best) best.classList.add('cc-hovered');
  }

  clearHover(map) {
    map
      .querySelectorAll('.cc-hovered')
      .forEach((d) => d.classList.remove('cc-hovered'));
  }
};
