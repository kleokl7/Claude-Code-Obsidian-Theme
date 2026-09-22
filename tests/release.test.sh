#!/usr/bin/env bash
#
# release.test.sh — exercise release.sh without touching GitHub.
#
# Each case runs release.sh in a throwaway copy of the repo whose `origin`
# is a local bare repo, with a fake `gh` first on PATH. The fake keeps
# releases as folders (one empty file per attached asset) and can be told
# to drop files on create (FAKE_GH_DROP) or to ignore uploads
# (FAKE_GH_UPLOAD_NOOP) — the failure seen on the real 1.3.0 release.
#
# Usage:
#   ./tests/release.test.sh
#
# Exits 1 if any case fails.

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

# Isolate git from the user's config (signing, hooks, default branch...).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# --- Fake gh ---
mkdir -p "$ROOT/bin"
cat > "$ROOT/bin/gh" <<'GHEOF'
#!/usr/bin/env bash
set -euo pipefail
S="$FAKE_GH_STATE"
case "$1 $2" in
    "auth status") exit 0 ;;
    "release view")
        tag="$3"
        [[ -d "$S/$tag" ]] || { echo "release not found" >&2; exit 1; }
        if [[ "${4:-}" == "--json" ]]; then
            if [[ "$5" == "assets" ]]; then ls "$S/$tag"; else echo "  tag: $tag"; fi
        fi ;;
    "release create")
        tag="$3"; shift 3
        mkdir -p "$S/$tag"
        for f in "$@"; do
            [[ "$f" == --* ]] && break
            [[ " ${FAKE_GH_DROP:-} " == *" $f "* ]] && continue
            touch "$S/$tag/$f"
        done ;;
    "release upload")
        tag="$3"; shift 3
        [[ -n "${FAKE_GH_UPLOAD_NOOP:-}" ]] && exit 0
        for f in "$@"; do [[ "$f" == --* ]] || touch "$S/$tag/$f"; done ;;
    *) echo "fake gh: unhandled: $*" >&2; exit 2 ;;
esac
GHEOF
chmod +x "$ROOT/bin/gh"
export PATH="$ROOT/bin:$PATH"

# --- Sandbox per case ---
N=0
setup() {
    N=$((N + 1))
    SB="$ROOT/case$N"
    mkdir -p "$SB/work/scripts" "$SB/work/companion" "$SB/gh"
    cp "$REPO"/{release.sh,theme.css,manifest.json,versions.json} "$SB/work/"
    cp "$REPO/scripts/check.sh" "$SB/work/scripts/"
    cp -R "$REPO/companion/claude-scroll-map" "$SB/work/companion/"
    git init -q --bare "$SB/origin.git"
    (
        cd "$SB/work"
        git init -q -b main
        git add -A && git commit -qm init
        git remote add origin "$SB/origin.git"
        git push -q -u origin main 2>/dev/null
    )
    export FAKE_GH_STATE="$SB/gh"
    unset FAKE_GH_DROP FAKE_GH_UPLOAD_NOOP
    VER=$(python3 -c 'import json; print(json.load(open("'"$SB"'/work/manifest.json"))["version"])')
}

# commit_versions JSON — replace versions.json in the sandbox and commit it
commit_versions() {
    (cd "$SB/work" && printf '%s\n' "$1" > versions.json && git commit -qam "versions.json")
}

run_release() {
    OUT=$(cd "$SB/work" && ./release.sh "$@" 2>&1)
    CODE=$?
}

PASS=0; FAIL=0
check() {  # description, condition (evaluated)
    if eval "$2"; then
        PASS=$((PASS + 1)); echo "✓ $1"
    else
        FAIL=$((FAIL + 1)); echo "✗ $1"; echo "$OUT" | sed 's/^/    /'
    fi
}
assets() { ls "$SB/gh/$VER" 2>/dev/null | tr '\n' ' '; }
FULL="manifest.json theme.css versions.json "

# 1. Happy path
setup; run_release --notes "test"
check "clean release attaches all three files" '[[ $CODE == 0 && "$(assets)" == "$FULL" ]]'
check "clean release pushes the tag" 'git -C "$SB/origin.git" rev-parse -q --verify "refs/tags/$VER" >/dev/null'

# 2. Create drops theme.css (the 1.3.0 failure) -> repaired
setup; export FAKE_GH_DROP="theme.css"; run_release
check "dropped theme.css is uploaded again" '[[ $CODE == 0 && "$(assets)" == "$FULL" && "$OUT" == *"uploading again"* ]]'

# 3. Create drops it and the upload silently does nothing -> hard failure
setup; export FAKE_GH_DROP="theme.css" FAKE_GH_UPLOAD_NOOP=1; run_release
check "a file still absent after upload fails the run" '[[ $CODE != 0 && "$OUT" == *"lacks: theme.css"* ]]'

# 4. Tag pushed on HEAD, release never created -> resume
setup; (cd "$SB/work" && git tag "$VER" && git push -q origin "$VER" 2>/dev/null); run_release
check "tag at HEAD without a release resumes" '[[ $CODE == 0 && "$(assets)" == "$FULL" && "$OUT" == *"resuming"* ]]'

# 5. Re-run after a complete release -> verifies, changes nothing
run_release
check "re-run on a complete release only verifies" '[[ $CODE == 0 && "$OUT" == *"already exists"* && "$(assets)" == "$FULL" ]]'

# 6. Tag on an older commit -> refuse
setup; (cd "$SB/work" && git tag "$VER" && echo x >> LICENSE-x && git add -A && git commit -qm more); run_release
check "tag on another commit is refused" '[[ $CODE != 0 && "$OUT" == *"another commit"* && -z "$(assets)" ]]'

# 7-9. versions.json guard: the three bugs the old grep guard had or risked
setup; commit_versions '{ "1.3.1": "'"$VER"'" }'; run_release
check "guard: version present only as a value is refused" '[[ $CODE != 0 && "$OUT" == *"versions.json needs"* && -z "$(assets)" ]]'
setup; commit_versions '{ "'"${VER//./x}"'": "1.5.0" }'; run_release
check "guard: dots are not wildcards" '[[ $CODE != 0 && "$OUT" == *"versions.json needs"* && -z "$(assets)" ]]'
setup; commit_versions '{ "'"$VER"'": "0.15.0" }'; run_release
check "guard: wrong minAppVersion is refused" '[[ $CODE != 0 && "$OUT" == *"versions.json needs"* && -z "$(assets)" ]]'

# 10. Dirty tree -> refuse
setup; echo "dirty" >> "$SB/work/theme.css"; run_release
check "dirty tree is refused" '[[ $CODE != 0 && "$OUT" == *"dirty"* && -z "$(assets)" ]]'

# 11-13. --verify (read-only)
setup; mkdir -p "$SB/gh/9.9.9"; touch "$SB/gh/9.9.9/"{theme.css,manifest.json,versions.json}
run_release --verify 9.9.9
check "--verify passes on a complete release and releases nothing" '[[ $CODE == 0 && "$OUT" == *"has theme.css"* && -z "$(assets)" ]]'
rm "$SB/gh/9.9.9/versions.json"; run_release --verify 9.9.9
check "--verify names the absent file" '[[ $CODE != 0 && "$OUT" == *"lacks: versions.json"* ]]'
run_release --verify 0.0.1
check "--verify fails on a release that does not exist" '[[ $CODE != 0 && "$OUT" == *"No GitHub release 0.0.1"* ]]'

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL == 0 ]]
