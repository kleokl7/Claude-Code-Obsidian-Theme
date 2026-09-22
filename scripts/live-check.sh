#!/usr/bin/env bash
#
# live-check.sh — render the test notes (tests/fixtures) in a real Obsidian
# window and check the behavior that has broken before: scroll-map marker
# positions and fill, the mobile bar, custom task states under the Tasks
# plugin, unresolved links, and console errors. Screenshots of every
# combination land in a folder for a visual pass.
#
# It runs in its own vault, test-vault/ at the repo root (git-ignored),
# never in your real vaults: nothing syncs, and scheme / mobile-emulation
# switches stay in that window. The first run opens it as a new Obsidian
# window; Tasks and Style Settings are copied from the first vault in
# .dev-vaults that has them.
#
# Usage:
#   ./scripts/live-check.sh               # refresh + deploy, check, screenshot
#   ./scripts/live-check.sh --no-shots    # checks only (faster)
#   ./scripts/live-check.sh --no-deploy   # test whatever theme/plugin files
#                                         # test-vault/ already has (used to
#                                         # prove a check catches a bug)
#   ./scripts/live-check.sh --out DIR     # screenshot folder (default: temp)
#
# Needs Obsidian running with any vault open. Exits 1 if any check fails.

set -uo pipefail
source "$(dirname "$0")/lib-obsidian.sh"

SHOTS=1; DEPLOY=""; OUT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-shots)  SHOTS=""; shift ;;
        --no-deploy) DEPLOY="--no-deploy"; shift ;;
        --out)       OUT="${2:?--out needs a folder}"; shift 2 ;;
        *) echo "✗ Unknown argument: $1" >&2; exit 1 ;;
    esac
done
if [[ -n "$SHOTS" ]]; then
    OUT="${OUT:-$(mktemp -d -t cc-live-check)}"
    mkdir -p "$OUT"
    OUT="$(cd "$OUT" && pwd)"   # dev:screenshot needs an absolute path
fi

build_test_vault $DEPLOY
open_test_vault || exit 1
tv dev:errors clear >/dev/null
# Fixed geometry, so screenshots compare run to run
tv eval code="require('@electron/remote').getCurrentWindow().setSize(1000, 1100)" >/dev/null

PASS=0; FAIL=0
# report LABEL JSON — print each { name, ok, detail } and count them
report() {
    local lines
    lines=$(python3 - "$1" "$2" <<'PYEOF'
import json, sys
label, raw = sys.argv[1], sys.argv[2]
try:
    results = json.loads(raw)
except ValueError:
    print(f"✗ {'eval':<13} {label}: {raw.strip()[:300] or 'no output'}")
    sys.exit()
for r in results:
    mark = "✓" if r["ok"] else "✗"
    tail = "" if r["ok"] else f": {r.get('detail')}"
    print(f"{mark} {r['name']:<13} {label}{tail}")
PYEOF
)
    [[ -n "$lines" ]] || return 0
    echo "$lines"
    PASS=$((PASS + $(grep -c '^✓' <<<"$lines")))
    FAIL=$((FAIL + $(grep -c '^✗' <<<"$lines")))
}
shot() {
    [[ -n "$SHOTS" ]] || return 0
    shoot "$OUT/$1.png" || echo "! No screenshot for $1" >&2
    return 0
}

# Documented defaults must hold without Style Settings (checked once,
# before the matrix, which then runs with Style Settings back on)
CALL="ccCheck.noStyleSettings({note:'Scroll Map Demo.md'})"
report "light/live/desktop without Style Settings" "$(js "$CALL")"

for PLATFORM in desktop mobile; do
    if [[ $PLATFORM == mobile ]]; then
        tv eval code="app.emulateMobile(true); 'on'" >/dev/null
        sleep 8   # emulateMobile reloads the window
    fi
    for SCHEME in light dark; do
        for VIEW in live reading; do
            COMBO="$SCHEME/$VIEW/$PLATFORM"
            TAG="$SCHEME-$VIEW-$PLATFORM"
            for NOTE in "Scroll Map Demo" "Short note" "Tasks" "Links" "Blocks"; do
                # Built in a variable: macOS bash 3.2 brace-expands {a, b}
                # inside "$(... "...")" and would split the call at commas.
                CALL="ccCheck.open({note:'$NOTE.md', view:'$VIEW', scheme:'$SCHEME'})"
                report "$COMBO $NOTE" "$(js "$CALL")"
                SLUG="${NOTE// /-}"
                MOBILE_CHECK=""
                [[ $PLATFORM == mobile ]] && MOBILE_CHECK="'mobile-track',"
                case "$NOTE" in
                    "Scroll Map Demo")
                        shot "$SLUG-$TAG-0"
                        js "ccCheck.scroll(0.5)" >/dev/null
                        report "$COMBO $NOTE @50%" "$(js "ccCheck.measure([$MOBILE_CHECK 'fill-mid'])")"
                        shot "$SLUG-$TAG-50"
                        js "ccCheck.scroll(1)" >/dev/null
                        report "$COMBO $NOTE @100%" "$(js "ccCheck.measure(['fill-end'])")"
                        shot "$SLUG-$TAG-100" ;;
                    "Short note")
                        report "$COMBO $NOTE" "$(js "ccCheck.measure(['spread'])")"
                        shot "$SLUG-$TAG" ;;
                    "Tasks")
                        report "$COMBO $NOTE" "$(js "ccCheck.measure(['tasks'])")"
                        shot "$SLUG-$TAG" ;;
                    "Links")
                        report "$COMBO $NOTE" "$(js "ccCheck.measure(['links'])")"
                        shot "$SLUG-$TAG" ;;
                    *)
                        shot "$SLUG-$TAG" ;;
                esac
            done
        done
    done
done

# Back to desktop, then the console: every combination must have run clean
tv eval code="app.emulateMobile(false); 'off'" >/dev/null
sleep 8
ERRORS=$(tv dev:errors)
if [[ "$ERRORS" == *"No errors captured"* ]]; then
    report "all combinations" '[{"name":"console","ok":true}]'
else
    echo "$ERRORS" | sed 's/^/    /'
    report "all combinations" '[{"name":"console","ok":false,"detail":"errors above"}]'
fi
tv eval code="app.changeTheme('system'); 'restored'" >/dev/null

echo
echo "$PASS passed, $FAIL failed"
[[ -n "$SHOTS" ]] && echo "Screenshots: $OUT"
[[ $FAIL == 0 ]]
