#!/usr/bin/env bash
#
# dev-deploy.sh — copy the working copy of the theme (and the Claude Scroll
# Map companion) into your local vaults, then reload them in the running
# Obsidian app. Obsidian reads the vault copies, not the repo, so testing
# without this means testing stale CSS.
#
# Vault paths come from .dev-vaults at the repo root: git-ignored, one
# absolute path per line, # starts a comment. No personal path lands in
# the repo.
#
# Usage:
#   ./scripts/dev-deploy.sh                  # copy, reload, print dev:errors
#   ./scripts/dev-deploy.sh --check          # only compare; exit 1 on drift
#   ./scripts/dev-deploy.sh --vault <path>   # one vault instead of .dev-vaults
#   ./scripts/dev-deploy.sh --no-reload      # copy only
#
# What goes where:
#   theme.css + manifest.json → <vault>/.obsidian/themes/<manifest "name">/
#   companion files           → <vault>/.obsidian/plugins/claude-scroll-map/
#                               (only where that folder already exists)
# Reload only touches a vault whose active theme is this one, and a plugin
# only if it is enabled there.

set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$(pwd)"

CHECK=""; RELOAD=1; VAULTS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)     CHECK=1; shift ;;
        --no-reload) RELOAD=""; shift ;;
        --vault)     VAULTS+=("${2:?--vault needs a path}"); shift 2 ;;
        *) echo "✗ Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [[ ${#VAULTS[@]} -eq 0 ]]; then
    if [[ ! -f .dev-vaults ]]; then
        echo "✗ No .dev-vaults file. Create it with one vault path per line, e.g.:" >&2
        echo "    echo \"\$HOME/Documents/My Vault\" > .dev-vaults" >&2
        exit 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"                                   # strip comments
        line="$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [[ -n "$line" ]] && VAULTS+=("${line/#\~/$HOME}")
    done < .dev-vaults
fi

THEME_NAME=$(python3 -c 'import json; print(json.load(open("manifest.json"))["name"])')
PLUGIN_ID=claude-scroll-map
THEME_FILES=(theme.css manifest.json)
PLUGIN_FILES=(manifest.json main.js styles.css)

DRIFT=0
# sync SRC DEST — compare (--check) or copy one file, reporting the result
sync() {
    local src="$1" dest="$2" label="${2#"$VAULT"/}"
    if [[ -n "$CHECK" ]]; then
        if [[ ! -f "$dest" ]]; then echo "  MISSING $label"; DRIFT=1
        elif cmp -s "$src" "$dest"; then echo "  SAME    $label"
        else echo "  DIFF    $label"; DRIFT=1
        fi
    else
        cp "$src" "$dest"
    fi
}

obsidian_up() { [[ -n "$RELOAD" ]] && command -v obsidian >/dev/null && pgrep -x Obsidian >/dev/null; }

for VAULT in "${VAULTS[@]}"; do
    echo "→ $VAULT"
    if [[ ! -d "$VAULT/.obsidian" ]]; then
        echo "! Skipped: no vault at this path (no .obsidian folder)." >&2
        [[ -n "$CHECK" ]] && DRIFT=1
        continue
    fi

    THEME_DIR="$VAULT/.obsidian/themes/$THEME_NAME"
    [[ -n "$CHECK" ]] || mkdir -p "$THEME_DIR"
    for f in "${THEME_FILES[@]}"; do sync "$REPO/$f" "$THEME_DIR/$f"; done

    PLUGIN_DIR="$VAULT/.obsidian/plugins/$PLUGIN_ID"
    COPIED="theme"
    if [[ -d "$PLUGIN_DIR" ]]; then
        for f in "${PLUGIN_FILES[@]}"; do sync "$REPO/companion/$PLUGIN_ID/$f" "$PLUGIN_DIR/$f"; done
        COPIED="theme and companion plugin"
    else
        echo "  (companion plugin not installed here — skipped)"
    fi
    [[ -n "$CHECK" ]] && continue
    echo "  copied $COPIED"

    if ! obsidian_up; then
        [[ -n "$RELOAD" ]] && echo "  Obsidian is not running — skipped the reload."
        continue
    fi
    NAME="$(basename "$VAULT")"
    # readThemes() re-reads theme folders + manifests (else Obsidian keeps
    # showing the old version; Obsidian <= 1.12 did this in loadData(), which
    # 1.13 narrowed to config only); setTheme() re-applies the CSS. Only if
    # this theme is the vault's active one — never switch someone's theme.
    OUT=$(obsidian vault="$NAME" eval code="(async()=>{const c=app.customCss;await (c.readThemes?c.readThemes():c.loadData());const n='$THEME_NAME';if(app.customCss.theme!==n)return 'theme not active ('+(app.customCss.theme||'default')+') — not reloaded';app.customCss.setTheme(n);return 'theme reloaded, version '+app.customCss.themes[n].version+(app.plugins.enabledPlugins.has('$PLUGIN_ID')?' | plugin enabled':' | plugin not enabled')})()" 2>&1) || true
    if [[ "$OUT" == *"Vault not found"* ]]; then
        echo "  Obsidian does not know a vault named \"$NAME\" — skipped the reload."
        continue
    fi
    echo "  ${OUT#=> }"
    if [[ "$OUT" == *"plugin enabled"* ]]; then
        obsidian vault="$NAME" plugin:reload id="$PLUGIN_ID" | sed 's/^/  /'
    fi
    echo "  dev:errors:"
    obsidian vault="$NAME" dev:errors 2>&1 | sed 's/^/    /'
done

if [[ -n "$CHECK" ]]; then
    if [[ $DRIFT == 0 ]]; then echo "✓ All vault copies match the repo."
    else echo "✗ Vault copies differ from the repo — run ./scripts/dev-deploy.sh"; fi
    exit "$DRIFT"
fi
