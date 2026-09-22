# lib-obsidian.sh — shared helpers for scripts that drive a running
# Obsidian through its CLI (live-check.sh, readme-shots.sh). Source it;
# it defines functions only.
#
# Lessons baked in (each cost a session some time):
#   - The CLI blocks forever while Obsidian shows a NATIVE dialog (e.g. the
#     "Vault not found" alert an obsidian://open?path=... link raises for an
#     unknown vault) — so every call here has a time limit, and vaults are
#     opened through Obsidian's own vault-open IPC, never through that URL.
#   - A vault window that is still loading can break if CLI calls hit it
#     (its theme loader came up with styleEl = null) — wait before the
#     first call, and reload the window once for a clean start.
#   - eval awaits a returned promise; top-level `await` is a syntax error,
#     so async code goes inside an async function.
#   - app.emulateMobile() reloads the window: globals do not survive, so
#     toggle it in its own call and wait.
#   - A window covered by another app stops rendering (frozen scroll
#     animations, empty reading view, crawling timers): live-check.js
#     turns background throttling off for the test vault window.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_VAULT="$REPO/test-vault"
TEST_VAULT_NAME="$(basename "$TEST_VAULT")"
CHECK_LIB="$REPO/scripts/live-check.js"
OBT="${OBT:-30}"   # seconds before a CLI call is abandoned

# ob ARGS... — the obsidian CLI with a time limit
ob() {
    local out pid i=0
    out=$(mktemp)
    obsidian "$@" >"$out" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        sleep 0.25
        i=$((i + 1))
        if (( i > OBT * 4 )); then
            # obsidian-cli can ignore SIGTERM and outlive the script
            kill "$pid" 2>/dev/null; sleep 0.5; kill -9 "$pid" 2>/dev/null
            echo "!! obsidian CLI timed out after ${OBT}s ($1 $2). A native Obsidian dialog may be open." >&2
            rm -f "$out"
            return 1
        fi
    done
    cat "$out"
    rm -f "$out"
}

# pil_python — print a python3 that can import PIL. The first python3 on
# PATH may not have it (on the owner's Mac, Homebrew's doesn't; the
# python.org one in /usr/local/bin does).
pil_python() {
    local p
    for p in $(which -a python3 2>/dev/null) /usr/local/bin/python3; do
        "$p" -c 'import PIL' 2>/dev/null && { echo "$p"; return 0; }
    done
    echo "✗ No python3 with PIL found — install it: python3 -m pip install pillow" >&2
    return 1
}

# tv ARGS... — the CLI against the test vault
tv() { ob vault="$TEST_VAULT_NAME" "$@"; }

# shoot FILE — screenshot the test vault window to FILE (absolute path).
# dev:screenshot sometimes writes the file and then never exits, so wait
# briefly and judge by the file, not by the CLI. Returns 1 if no file.
shoot() {
    rm -f "$1"
    OBT=12 tv dev:screenshot path="$1" >/dev/null 2>&1
    [[ -s "$1" ]]
}

# js CALL — run live-check.js plus one call in the test vault; prints the
# call's result without the CLI's "=> " prefix
js() {
    tv eval code="$(cat "$CHECK_LIB")
$1" | sed 's/^=> //'
}

# copy_plugin ID — copy a community plugin into the test vault from the
# first vault in .dev-vaults that has it (main.js, manifest.json, styles.css)
copy_plugin() {
    local id="$1" dest="$TEST_VAULT/.obsidian/plugins/$1" line src
    [[ -f "$dest/main.js" ]] && return 0
    [[ -f "$REPO/.dev-vaults" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [[ -n "$line" ]] || continue
        src="${line/#\~/$HOME}/.obsidian/plugins/$id"
        if [[ -f "$src/main.js" ]]; then
            mkdir -p "$dest"
            cp "$src/main.js" "$src/manifest.json" "$dest/"
            [[ -f "$src/styles.css" ]] && cp "$src/styles.css" "$dest/"
            return 0
        fi
    done < "$REPO/.dev-vaults"
    return 1
}

# build_test_vault [--no-deploy] — create/refresh the test vault: fixture
# notes, Tasks + Style Settings (copied from your vaults), theme + companion
build_test_vault() {
    mkdir -p "$TEST_VAULT/.obsidian/plugins/claude-scroll-map"
    cp "$REPO/tests/fixtures/"*.md "$TEST_VAULT/"
    copy_plugin obsidian-tasks-plugin ||
        echo "! Tasks plugin not found in any .dev-vaults vault — task checks run on stock markup only." >&2
    copy_plugin obsidian-style-settings ||
        echo "! Style Settings not found in any .dev-vaults vault — the progress bar will be off." >&2
    # Warm code blocks, like the owner's own setup (and the README images)
    local ss="$TEST_VAULT/.obsidian/plugins/obsidian-style-settings/data.json"
    [[ -d "$(dirname "$ss")" && ! -f "$ss" ]] &&
        printf '{\n  "claude-code-theme@@cc-loud-code": false\n}\n' > "$ss"
    if [[ "${1:-}" != "--no-deploy" ]]; then
        "$REPO/scripts/dev-deploy.sh" --vault "$TEST_VAULT" --no-reload >/dev/null
    fi
}

# open_test_vault — make sure Obsidian runs and the test vault window is
# open, with the theme and plugins enabled, freshly reloaded. Returns 1
# (with a message) when that cannot be reached.
open_test_vault() {
    if ! pgrep -x Obsidian >/dev/null; then
        echo "✗ Obsidian is not running. Start it (any vault) and run this again." >&2
        return 1
    fi
    if [[ "$(tv eval code="app.vault.getName()")" != "=> $TEST_VAULT_NAME" ]]; then
        echo "→ Opening the test vault in a new Obsidian window"
        local r
        r=$(ob eval code="String(require('electron').ipcRenderer.sendSync('vault-open', $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$TEST_VAULT"), false))")
        if [[ "$r" != "=> true" ]]; then
            echo "✗ Obsidian could not open $TEST_VAULT: $r" >&2
            return 1
        fi
        # First open indexes the vault; no CLI calls until it has written
        # its workspace, then a little longer.
        local i
        for i in $(seq 1 60); do
            [[ -f "$TEST_VAULT/.obsidian/workspace.json" ]] && break
            sleep 1
        done
        sleep 8
    fi
    # Theme + plugins on (idempotent), then one reload for a clean start.
    tv eval code="(async()=>{const c=app.customCss;await c.readThemes();if(c.theme!=='Claude Code Orange')c.setTheme('Claude Code Orange');await app.plugins.loadManifests();for(const id of ['obsidian-style-settings','obsidian-tasks-plugin','claude-scroll-map']){if(app.plugins.manifests[id]&&!app.plugins.enabledPlugins.has(id))await app.plugins.enablePluginAndSave(id)}if(document.body.classList.contains('is-mobile'))app.emulateMobile(false);setTimeout(()=>location.reload(),300);return 'ok'})()" >/dev/null
    sleep 12
    local state
    state=$(tv eval code="JSON.stringify({ready:app.workspace.layoutReady, css:!!(app.customCss.styleEl&&app.customCss.styleEl.textContent.includes('CLAUDE CODE ORANGE')), bar:document.body.classList.contains('cc-scroll-progress'), map:app.plugins.enabledPlugins.has('claude-scroll-map')})")
    if [[ "$state" != *'"ready":true'* || "$state" != *'"css":true'* || "$state" != *'"map":true'* ]]; then
        echo "✗ The test vault did not come up cleanly: ${state#=> }" >&2
        echo "  Reload its window (Cmd+R) and run this again." >&2
        return 1
    fi
    [[ "$state" == *'"bar":true'* ]] ||
        echo "! Progress bar class missing (Style Settings absent?) — scroll checks will fail." >&2
    return 0
}
