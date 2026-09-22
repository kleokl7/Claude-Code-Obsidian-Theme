/* live-check.js — runs INSIDE Obsidian through `obsidian eval`.
   scripts/lib-obsidian.sh sends this whole file plus one call, e.g.
     ccCheck.open({ note: 'Tasks.md', view: 'reading', scheme: 'light' })
   and every call resolves to a JSON string. Plain ES2017 and block
   comments only. Each check returns { name, ok, detail } and encodes a
   bug that once shipped or nearly shipped:
     spread        markers on a note that fits the window must not pile
                   up at the right edge                     (2026-07-07)
     fill-mid/end  markers fill as the progress line passes them
                                                  (2026-07-07, 07-09/10)
     mobile-track  the mobile bar uses --cc-track-color (light-mode fix
                   95d6092 first missed mobile)             (2026-09-22)
     tasks         custom states with the Tasks plugin's reading-view
                   markup: no strike, no tick on / and >   (2026-09-09)
     links         unresolved links dotted, resolved ones plain */
var ccCheck = (function () {
  var sleep = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };

  /* The leaf on screen: the active one when it is markdown. (A hidden
     markdown leaf can survive a mobile-emulation reload; opening notes
     there passed the path check while the screen showed the old note.) */
  function leaf() {
    var a = app.workspace.activeLeaf;
    if (a && a.view && a.view.getViewType() === 'markdown') return a;
    return app.workspace.getLeavesOfType('markdown')[0] || app.workspace.getLeaf(false);
  }
  function scroller(v) {
    return v.getMode() === 'preview'
      ? v.containerEl.querySelector('.markdown-preview-view')
      : v.containerEl.querySelector('.cm-scroller');
  }
  function rgb(hex) {
    var h = hex.trim().replace('#', '');
    if (h.length === 3) h = h.split('').map(function (c) { return c + c; }).join('');
    var n = parseInt(h, 16);
    return 'rgb(' + ((n >> 16) & 255) + ', ' + ((n >> 8) & 255) + ', ' + (n & 255) + ')';
  }
  function res(name, ok, detail) { return { name: name, ok: !!ok, detail: detail }; }
  function dots(v) {
    var map = v.containerEl.querySelector('.cc-scroll-map');
    if (!map) return [];
    return [].slice.call(map.querySelectorAll('.cc-scroll-dot')).map(function (d) {
      return {
        left: parseFloat(d.style.left),
        fill: parseFloat(getComputedStyle(d, '::before').opacity)
      };
    });
  }

  async function open(o) {
    /* When another app covers this window, Chromium stops rendering it:
       scroll-driven animations freeze, reading view renders nothing and
       timers crawl. Keep it live so the check can run in the background. */
    try { require('@electron/remote').getCurrentWebContents().setBackgroundThrottling(false); } catch (e) { /* not desktop */ }
    app.changeTheme(o.scheme === 'dark' ? 'obsidian' : 'moonstone');
    var lf = leaf();
    app.workspace.getLeavesOfType('markdown').forEach(function (l) { if (l !== lf) l.detach(); });
    await lf.setViewState({
      type: 'markdown', active: true,
      state: { file: o.note, mode: o.view === 'reading' ? 'preview' : 'source', source: false }
    });
    app.workspace.setActiveLeaf(lf, { focus: true });
    if (!app.isMobile) { app.workspace.leftSplit.collapse(); app.workspace.rightSplit.collapse(); }
    await sleep(1200);   /* companion debounce (250 ms) + render */
    var v = lf.view, shown = v && v.containerEl.offsetParent !== null;
    var ok = shown && v.file && v.file.path === o.note &&
      v.getMode() === (o.view === 'reading' ? 'preview' : 'source');
    return JSON.stringify([res('open', ok, ok ? '' : 'on screen: ' +
      (v && v.file ? v.file.path + ' (' + v.getMode() + ')' : 'nothing') + (shown ? '' : ', leaf hidden'))]);
  }

  /* README storefront: the demo note in Live Preview with the cursor parked
     on the last (empty) line, so every block renders as a widget. */
  async function demo(o) {
    await open({ note: o.note, view: 'live', scheme: o.scheme });
    var ed = leaf().view.editor;
    ed.setCursor(ed.lastLine(), 0);
    ed.blur();
    /* the cursor line would carry the active-line tint as a stray band */
    document.body.classList.remove('cc-active-line');
    await sleep(600);
    return JSON.stringify([]);
  }

  /* README scroll-map crop: scroll a heading to the top, show its marker's
     tooltip, and return the crop origin (CSS px): the note's title row. */
  async function strip(o) {
    await open({ note: o.note, view: 'live', scheme: o.scheme });
    var v = leaf().view;
    var h = app.metadataCache.getFileCache(v.file).headings
      .filter(function (x) { return x.heading === o.heading; })[0];
    if (h) {
      /* Scroll the heading just past the top edge (its marker has filled)
         so its first paragraph sits under the strip. Two steps: bring it
         into view, then correct by its real screen offset — the scroller
         has padding and the inline title above the text. */
      var cm = v.editor.cm, from = cm.state.doc.line(h.position.start.line + 1).from;
      cm.scrollDOM.scrollTop = cm.lineBlockAt(from).top;
      await sleep(300);
      var c = cm.coordsAtPos(from);
      if (c) cm.scrollDOM.scrollTop += c.top - cm.scrollDOM.getBoundingClientRect().top + 45;
    }
    await sleep(900);
    var dot = [].slice.call(v.containerEl.querySelectorAll('.cc-scroll-dot'))
      .filter(function (d) { return d.dataset.label === o.heading; })[0];
    if (dot) dot.classList.add('cc-hovered');
    await sleep(300);
    var hdr = v.containerEl.querySelector('.view-header').getBoundingClientRect();
    var box = v.containerEl.getBoundingClientRect();
    return JSON.stringify({ found: !!dot, x: box.left, y: hdr.top, w: box.width, dpr: devicePixelRatio });
  }

  async function scroll(frac) {
    var s = scroller(leaf().view);
    s.scrollTop = frac * (s.scrollHeight - s.clientHeight);
    await sleep(500);
    return JSON.stringify([]);
  }

  var checks = {
    spread: function (v) {
      var d = dots(v), lefts = d.map(function (x) { return x.left; });
      var distinct = new Set(lefts.map(function (l) { return l.toFixed(1); })).size;
      return res('spread', d.length >= 3 && distinct === d.length &&
        lefts.every(function (l) { return l < 95; }), 'left % = ' + lefts.join(', '));
    },
    'fill-mid': function (v) {
      var d = dots(v), filled = d.filter(function (x) { return x.fill >= 0.99; }).length;
      return res('fill-mid', d.length > 1 && filled > 0 && filled < d.length,
        filled + ' of ' + d.length + ' filled at 50%');
    },
    'fill-end': function (v) {
      var d = dots(v), filled = d.filter(function (x) { return x.fill >= 0.99; }).length;
      return res('fill-end', d.length > 0 && filled === d.length,
        filled + ' of ' + d.length + ' filled at 100%');
    },
    'mobile-track': function (v) {
      var vc = v.containerEl.querySelector('.view-content');
      var bg = getComputedStyle(vc, '::before').backgroundImage;
      var want = rgb(getComputedStyle(document.body).getPropertyValue('--cc-track-color'));
      return res('mobile-track', bg.indexOf(want) >= 0, 'want ' + want + ' in ' + bg.slice(0, 70));
    },
    tasks: function (v) {
      /* Reading view: <li data-task> (the Tasks plugin leaves the <input>
         bare). Live Preview: .HyperMD-task-line[data-task]. */
      var items = [].slice.call(v.containerEl.querySelectorAll(
        v.getMode() === 'preview' ? 'li.task-list-item' : '.HyperMD-task-line[data-task]'));
      var want = {
        ' ': { strike: false },
        '/': { strike: false, gradient: true, tick: false },
        '>': { strike: false, chevron: true },
        'x': { strike: true },
        '-': { strike: true, gradient: true }
      };
      var bad = [], seen = 0;
      items.forEach(function (el) {
        var state = el.dataset.task || ' ', w = want[state], cb = el.querySelector('input');
        if (!w || !cb) return;
        seen++;
        var after = getComputedStyle(cb, '::after');
        var got = {
          strike: getComputedStyle(el).textDecorationLine.indexOf('line-through') >= 0,
          gradient: getComputedStyle(cb).backgroundImage.indexOf('linear-gradient') >= 0,
          tick: after.display !== 'none',
          chevron: after.display !== 'none' && (after.maskImage || after.webkitMaskImage || '').indexOf('url(') >= 0
        };
        Object.keys(w).forEach(function (k) {
          if (got[k] !== w[k]) bad.push('[' + state + '] ' + k + '=' + got[k]);
        });
      });
      return res('tasks', seen === 5 && bad.length === 0,
        seen !== 5 ? 'found ' + seen + ' of 5 task items' : bad.join('; '));
    },
    links: function (v) {
      var root = v.containerEl, un, ok;
      if (v.getMode() === 'preview') {
        un = root.querySelector('a.internal-link.is-unresolved');
        ok = root.querySelector('a.internal-link:not(.is-unresolved)');
      } else {
        un = root.querySelector('.cm-hmd-internal-link .is-unresolved .cm-underline');
        ok = [].slice.call(root.querySelectorAll('.cm-hmd-internal-link .cm-underline'))
          .filter(function (e) { return !e.closest('.is-unresolved'); })[0];
      }
      if (!un || !ok) return res('links', false, 'link elements not found');
      var u = getComputedStyle(un), r = getComputedStyle(ok);
      return res('links',
        u.textDecorationLine.indexOf('underline') >= 0 && u.textDecorationStyle === 'dotted' &&
        r.textDecorationLine === 'none',
        'unresolved: ' + u.textDecorationLine + ' ' + u.textDecorationStyle +
        '; resolved: ' + r.textDecorationLine);
    }
  };

  /* Without Style Settings its class-toggles never reach <body>, yet the
     options must keep their documented defaults: progress bar on, active
     line tinted, loud (blue) code blocks. Disables the plugin for the
     check and restores it (without saving either change). */
  async function noStyleSettings(o) {
    var id = 'obsidian-style-settings', had = app.plugins.enabledPlugins.has(id);
    if (had) await app.plugins.disablePlugin(id);
    await open({ note: o.note, view: 'live', scheme: 'light' });
    var v = leaf().view;
    v.editor.setCursor(0, 0);
    await sleep(300);
    var bar = getComputedStyle(v.containerEl.querySelector('.view-content'), '::after').content;
    var line = v.containerEl.querySelector('.cm-active.cm-line');
    var lineBg = line ? getComputedStyle(line).backgroundColor : 'no active line';
    var code = getComputedStyle(document.body).getPropertyValue('--cc-code-bg').trim();
    var out = [
      res('no-ss-bar', bar !== 'none', 'progress bar ::after content = ' + bar),
      res('no-ss-line', lineBg !== 'rgba(0, 0, 0, 0)' && lineBg !== 'no active line', 'active line bg = ' + lineBg),
      res('no-ss-code', code === '#eaf1fd', '--cc-code-bg = ' + code + ' (loud light = #eaf1fd)')
    ];
    if (had) { await app.plugins.enablePlugin(id); await sleep(800); }
    return JSON.stringify(out);
  }

  function measure(names) {
    var v = leaf().view;
    return JSON.stringify(names.map(function (n) { return checks[n](v); }));
  }

  return { open: open, scroll: scroll, measure: measure, demo: demo, strip: strip,
    noStyleSettings: noStyleSettings };
})();
