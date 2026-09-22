#!/usr/bin/env bash
#
# check.sh — static checks that need no Obsidian: run before every release
# (release.sh calls it first) and after any scripted edit to theme.css.
#
# Checks:
#   - manifest.json, versions.json and the companion manifest parse as JSON
#   - versions.json has "<manifest version>": "<manifest minAppVersion>"
#   - the companion plugin's main.js parses (node --check)
#   - theme.css: braces balance, no "/*" inside a comment (a garbled
#     banner once slipped in this way), and the section banners match the
#     Contents list at the top of the file
#
# Usage:
#   ./scripts/check.sh
#
# Exits 1 if any check fails.

set -euo pipefail
cd "$(dirname "$0")/.."

FAIL=0

python3 - <<'PYEOF' || FAIL=1
import json, re, sys

ok = True
def bad(msg):
    global ok
    ok = False
    print(f"✗ {msg}", file=sys.stderr)

# --- JSON files ---
docs = {}
for path in ("manifest.json", "versions.json", "companion/claude-scroll-map/manifest.json"):
    try:
        with open(path) as f:
            docs[path] = json.load(f)
    except (OSError, ValueError) as e:
        bad(f"{path}: {e}")

# --- versions.json entry for the manifest version ---
m, v = docs.get("manifest.json"), docs.get("versions.json")
if m is not None and v is not None:
    ver, minapp = m.get("version"), m.get("minAppVersion")
    if not ver or not minapp:
        bad("manifest.json needs both \"version\" and \"minAppVersion\"")
    elif v.get(ver) != minapp:
        bad(f"versions.json needs the entry \"{ver}\": \"{minapp}\" "
            f"(matching manifest.json's minAppVersion); it has {json.dumps(v.get(ver))}")

# --- theme.css structure ---
css = open("theme.css").read()

def line_of(i):
    return css.count("\n", 0, i) + 1

depth, i, n = 0, 0, len(css)
while i < n:
    if css.startswith("/*", i):
        end = css.find("*/", i + 2)
        if end < 0:
            bad(f"theme.css:{line_of(i)}: comment never closes")
            break
        inner = css.find("/*", i + 2, end)
        if inner >= 0:
            bad(f"theme.css:{line_of(inner)}: \"/*\" inside a comment (garbled banner or unclosed comment?)")
        i = end + 2
        continue
    c = css[i]
    if c in "\"'":
        end = i + 1
        while end < n and css[end] != c:
            end += 2 if css[end] == "\\" else 1
        i = end + 1
        continue
    if c == "{":
        depth += 1
    elif c == "}":
        depth -= 1
        if depth < 0:
            bad(f"theme.css:{line_of(i)}: \"}}\" without a matching \"{{\"")
            depth = 0
    i += 1
if depth > 0:
    bad(f"theme.css: {depth} unclosed \"{{\" at end of file")

toc_block = re.search(r"Contents\n(.*?)\n\s*=+ \*/", css, re.S)
toc = re.findall(r"^\s+(\d+)\.\s+(\S+(?: \S+)?)\s{2,}", toc_block.group(1), re.M) if toc_block else []
banners = re.findall(r"^/\* =+\n   (\d+)\. ([^\n]*)", css, re.M)
if not toc:
    bad("theme.css: no Contents list found in the header comment")
elif [int(t[0]) for t in toc] != list(range(1, len(toc) + 1)):
    bad(f"theme.css: Contents numbering is not 1..{len(toc)}")
if [int(b[0]) for b in banners] != list(range(1, len(banners) + 1)):
    bad("theme.css: section banners are not numbered 1..N in order: "
        + ", ".join(b[0] for b in banners))
if toc and len(toc) != len(banners):
    bad(f"theme.css: Contents lists {len(toc)} sections, the file has {len(banners)} banners")
for (tn, tname), (bn, btitle) in zip(toc, banners):
    if tname.lower() not in btitle.lower():
        bad(f"theme.css: Contents item {tn} \"{tname}\" does not match banner {bn} \"{btitle.strip()}\"")

if ok:
    print("✓ JSON, versions.json entry, theme.css structure")
sys.exit(0 if ok else 1)
PYEOF

if command -v node >/dev/null 2>&1; then
    if node --check companion/claude-scroll-map/main.js; then
        echo "✓ companion main.js parses"
    else
        echo "✗ companion/claude-scroll-map/main.js does not parse" >&2
        FAIL=1
    fi
else
    echo "! node not found — skipped the main.js syntax check" >&2
fi

exit "$FAIL"
