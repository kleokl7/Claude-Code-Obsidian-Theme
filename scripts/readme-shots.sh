#!/usr/bin/env bash
#
# readme-shots.sh — regenerate the README and storefront images from the
# demo notes in tests/fixtures, rendered in the test vault (see
# live-check.sh). Writes:
#
#   theme-preview.png                       light | dark side by side — the
#                                           Obsidian directory's storefront
#   screenshots/preview-light.png           "Claude Code Orange.md", Live Preview
#   screenshots/preview-dark.png
#   screenshots/scroll-map-light.png        title row + scroll map strip with a
#   screenshots/scroll-map-dark.png         heading tooltip ("Scroll Map Demo.md")
#
# Code blocks render warm (Style Settings "Loud code blocks" off in the
# test vault) — the owner's choice for these images. Run after any visual
# change; the roadmap calls theme-preview.png the storefront.
#
# Usage:
#   ./scripts/readme-shots.sh
#
# Needs Obsidian running (any vault) and python3 with PIL.

set -uo pipefail
source "$(dirname "$0")/lib-obsidian.sh"

PY="$(pil_python)" || exit 1
TMP="$(mktemp -d -t cc-readme-shots)"
trap 'rm -rf "$TMP"' EXIT

build_test_vault
open_test_vault || exit 1
# Storefront framing (test vault only): no ribbon, no spellcheck squiggles,
# no red "Sync not set up" icon in the status bar
tv eval code="(async()=>{app.vault.setConfig('showRibbon', false); app.vault.setConfig('spellcheck', false); const s=app.internalPlugins.plugins.sync; if(s&&s.enabled) await s.disable(true); return 'ok'})()" >/dev/null

win() {   # win WIDTH HEIGHT (CSS px); the plugin re-lays the strip on resize
    tv eval code="require('@electron/remote').getCurrentWindow().setSize($1, $2)" >/dev/null
    sleep 1
}

FAILED=""
snap() {   # snap FILE — screenshot the test vault window, or flag failure
    shoot "$1" || { echo "✗ Screenshot failed: $1" >&2; FAILED=1; }
}
for SCHEME in light dark; do
    # Note preview: 737 x 1130 CSS px → 1474 x 2260 at 2x, the old size
    win 737 1130
    CALL="ccCheck.demo({note:'Claude Code Orange.md', scheme:'$SCHEME'})"
    js "$CALL" >/dev/null
    snap "$TMP/preview-$SCHEME.png"

    # Scroll map strip: a narrow window so the crop reads at README width
    win 601 1130
    CALL="ccCheck.strip({note:'Scroll Map Demo.md', heading:'Choosing the charcoal', scheme:'$SCHEME'})"
    BOX=$(js "$CALL")
    snap "$TMP/window-$SCHEME.png"
    # Crop box in image px: title row + strip + tooltip + two lines of
    # text, 126 CSS px tall, from the note's title row down
    CROP=$("$PY" -c '
import json, sys
b = json.loads(sys.argv[1])
if not b.get("found"):
    sys.exit("✗ no marker labelled with the heading (merged by clustering?): " + sys.argv[1])
s = b["dpr"]
print(round(b["x"] * s), round(b["y"] * s), round(b["w"] * s), round(126 * s))' "$BOX") &&
        "$PY" "$REPO/scripts/crop.py" "$TMP/window-$SCHEME.png" "$TMP/scroll-map-$SCHEME.png" $CROP >/dev/null ||
        FAILED=1
done
win 1000 1100
tv eval code="app.changeTheme('system'); 'restored'" >/dev/null

[[ -z "$FAILED" ]] || { echo "✗ Nothing written: a screenshot or crop failed (see above)." >&2; exit 1; }

# Storefront: light | dark side by side
"$PY" - "$TMP" <<'PYEOF'
import sys
from PIL import Image
t = sys.argv[1]
l, d = Image.open(f"{t}/preview-light.png"), Image.open(f"{t}/preview-dark.png")
out = Image.new("RGB", (l.width + d.width, max(l.height, d.height)))
out.paste(l.convert("RGB"), (0, 0))
out.paste(d.convert("RGB"), (l.width, 0))
out.save(f"{t}/theme-preview.png")
PYEOF

cp "$TMP/theme-preview.png" "$REPO/theme-preview.png"
for SCHEME in light dark; do
    cp "$TMP/preview-$SCHEME.png" "$REPO/screenshots/preview-$SCHEME.png"
    cp "$TMP/scroll-map-$SCHEME.png" "$REPO/screenshots/scroll-map-$SCHEME.png"
done
for f in theme-preview.png screenshots/preview-{light,dark}.png screenshots/scroll-map-{light,dark}.png; do
    echo "✓ $f  $("$PY" -c 'import sys; from PIL import Image; w,h=Image.open(sys.argv[1]).size; print(f"{w}x{h}")' "$REPO/$f")"
done
