#!/usr/bin/env bash
#
# install-scroll-map.sh — install the Claude Scroll Map companion plugin
# into an Obsidian vault, without hunting for folder paths.
#
# Usage:
#   ./scripts/install-scroll-map.sh /path/to/vault
#   ./scripts/install-scroll-map.sh            # prompts for the vault path
#
# Copies manifest.json, main.js and styles.css from companion/claude-scroll-map
# into <vault>/.obsidian/plugins/claude-scroll-map/. Safe to re-run to update.

set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/companion/claude-scroll-map"
FILES=(manifest.json main.js styles.css)

# --- Source sanity ---
for f in "${FILES[@]}"; do
    if [[ ! -f "$SRC/$f" ]]; then
        echo "✗ Missing $SRC/$f — run this from a full checkout of the theme repo." >&2
        exit 1
    fi
done

# --- Vault path: argument or prompt ---
VAULT="${1:-}"
if [[ -z "$VAULT" ]]; then
    # No -r: a drag-and-dropped folder arrives backslash-escaped
    # ("My\ Vault") and read's backslash handling unescapes it.
    read -e -p "Path to your Obsidian vault: " VAULT
fi
if [[ -z "$VAULT" ]]; then
    echo "Usage: $0 /path/to/vault" >&2
    exit 1
fi
# Expand a leading ~ (read doesn't)
VAULT="${VAULT/#\~/$HOME}"

if [[ ! -d "$VAULT" ]]; then
    echo "✗ Not a directory: $VAULT" >&2
    exit 1
fi
if [[ ! -d "$VAULT/.obsidian" ]]; then
    echo "✗ No .obsidian folder in $VAULT — is this really a vault?" >&2
    echo "  (Open the vault in Obsidian once if it is brand new.)" >&2
    exit 1
fi

# --- Install ---
DEST="$VAULT/.obsidian/plugins/claude-scroll-map"
mkdir -p "$DEST"
for f in "${FILES[@]}"; do
    cp "$SRC/$f" "$DEST/"
done

echo "✓ Claude Scroll Map installed to $DEST"
echo
echo "Next steps in Obsidian:"
echo "  1. Settings → Community plugins → enable community plugins (if not already)."
echo "  2. Enable “Claude Scroll Map” in the plugin list (or reload Obsidian if it was already enabled)."
