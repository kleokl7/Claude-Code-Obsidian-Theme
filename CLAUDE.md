# Claude Code Orange — notes for agents

An Obsidian theme (`theme.css`, one file, no build step) plus the Claude
Scroll Map companion plugin (`companion/claude-scroll-map`). Public repo:
personal paths never go in committed files — local vault paths live in
`.dev-vaults` (git-ignored).

## Commands

| Command | What it does |
| --- | --- |
| `./scripts/check.sh` | Static checks: JSON files, `versions.json` entry, `theme.css` braces / nested comments / banners vs Contents, plugin syntax. Run after any scripted edit. |
| `./scripts/dev-deploy.sh` | Copy theme + companion into the vaults in `.dev-vaults`, reload them in the running app, print `dev:errors`. `--check` only compares. |
| `./scripts/live-check.sh` | Render `tests/fixtures` in the isolated `test-vault/` window and check marker spread/fill, markers with the bar off, the mobile bar, Tasks-plugin task states, unresolved links and console errors; screenshots of every scheme × view × platform. `--no-shots`, `--no-deploy`. |
| `./scripts/readme-shots.sh` | Regenerate the README / storefront images from the demo fixtures. |
| `./tests/release.test.sh` | `release.sh` against a fake `gh` and a local bare remote. |
| `./release.sh --verify <ver>` | Read-only: does a GitHub release have all three files? |

## Working rules

- **Visual changes: preview first.** Before editing CSS for a visual change,
  show a mockup built from the exact values in `theme.css` (grep them — an
  approximate-hex mockup once made the coral look changed) and wait for
  approval.
- After an edit: `check.sh` → `dev-deploy.sh` → `live-check.sh` → look at
  the screenshots.
- Commit, push and release only when the owner asks. A release needs the
  `manifest.json` version bumped and a matching `versions.json` entry;
  companion changes bump `companion/claude-scroll-map/manifest.json` (the
  companion is not released on GitHub — users install it with
  `scripts/install-scroll-map.sh`).
- A behavior change is not done until its docs match: README text and
  images, the "Shipped" notes in `docs/implementation-roadmap.md`, and the
  section comments in `theme.css`.

## Known traps

- The companion's baseline `.cc-scroll-map .cc-scroll-dot[data-level=…]`
  rules outrank the theme's base `body .cc-scroll-map .cc-scroll-dot` rule,
  so per-level theme rules must restate `border-radius` and `background`.
- Chromium's scroll-driven animations miscompute color interpolation
  between `color-mix()` and hex endpoints (the fill came out neon yellow):
  animate `opacity` instead.
- Style Settings `class-toggle`s reach `body` only while Style Settings
  runs. A toggle with `default: true` must be written as
  `body:is(.cc-x, :not(.css-settings-manager))` (on when toggled, or when
  the plugin is absent) — see the note above the `@settings` block;
  `live-check.sh` checks it (`no-ss-*`). Don't rename a setting `id`: users'
  stored values are keyed `claude-code-theme@@<id>`.
- Live Preview tables carry `.markdown-rendered`, but stock
  `.markdown-source-view.mod-cm6 .cm-table-widget td { padding: 0 }`
  outranks the theme's cell padding (an inner `.table-cell-wrapper` pads).
  Stock `thead tr > th` paints header borders from `--table-*`: map those
  variables, don't fight the selector.
- The Tasks plugin re-renders reading-view tasks with `data-task` on the
  `<li>` (not the `<input>`) and marks every non-empty state `is-checked`.
- Live Preview unresolved link: `.cm-hmd-internal-link > .is-unresolved >
  .cm-underline`. Tooltips and notices both paint from
  `--background-modifier-message`.

## Obsidian CLI (`obsidian`; the app must be running)

`scripts/lib-obsidian.sh` wraps all of this; read it before driving the app
by hand.

- `vault=<name>` targets a vault. An unknown name prints `Vault not found.`
  and still exits 0.
- **Never** open `obsidian://open?path=…` for a vault Obsidian doesn't know:
  it raises a native "Vault not found" alert and every CLI call blocks until
  someone clicks OK. Open vaults with
  `require('electron').ipcRenderer.sendSync('vault-open', path, false)`.
- `eval` awaits a returned promise; top-level `await` is a syntax error, so
  wrap async code in an async function. Multi-line code works.
- Reload a theme with `app.customCss.readThemes()` then `setTheme(name)`.
  Since 1.13, `loadData()` only reads config.
- Switch scheme with `app.changeTheme('moonstone' | 'obsidian' | 'system')`.
  There is no `theme:use-dark` command.
- `app.emulateMobile(bool)` reloads the window: toggle it in its own call
  and wait ~8 s.
- A window covered by another app stops rendering: scroll-driven
  animations freeze, reading view renders nothing, timers crawl, CLI calls
  time out. `require('@electron/remote').getCurrentWebContents()
  .setBackgroundThrottling(false)` keeps it live (live-check.js does this) —
  don't bring Obsidian to the front while the owner works elsewhere.
- `dev:screenshot path=` must be absolute; a relative path writes into the
  vault root, where Obsidian indexes it.
- Crop screenshots with `scripts/crop.py` (PIL). `sips -c` crops around the
  centre and cost several retries. The first `python3` on this Mac's PATH
  (Homebrew) has no PIL; `/usr/local/bin/python3` does — scripts pick one
  with `pil_python` from `lib-obsidian.sh`.
- Scripts run under macOS's bash 3.2: no `mapfile`, and `{a, b}` inside
  `"$(cmd "…")"` gets brace-expanded — build JS calls in a variable first.
