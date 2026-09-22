#!/usr/bin/env bash
#
# release.sh — cut an Obsidian community-theme release.
#
# The Obsidian directory does NOT read the repo directly — it reads GitHub
# Releases, and requires a release whose tag EXACTLY equals the version in
# manifest.json (no "v" prefix). This script reads that version, sanity-
# checks the repo, then tags + pushes + creates the release with theme.css,
# manifest.json and versions.json attached — and verifies they really are
# attached (on 1.3.0, `gh release create` silently dropped theme.css).
#
# Usage:
#   ./release.sh                   # release the version in manifest.json
#   ./release.sh --notes "..."     # with custom release notes
#   ./release.sh --verify 1.5.0    # read-only: does that release have all files?
#
# Safe to re-run after a partial failure: when the tag already points at
# HEAD, the script resumes (creates the missing release or re-uploads the
# missing files) instead of refusing.
#
# Requires: git, gh (authenticated: gh auth status), python3 (check.sh).
# Tests: tests/release.test.sh (fake gh, local bare remote).

set -euo pipefail
cd "$(dirname "$0")"

ASSETS=(theme.css manifest.json versions.json)

NOTES="Theme update. Install/update via Settings → Appearance → Themes → Manage → \"Claude Code Orange\"."
VERIFY=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --notes)  NOTES="${2:?--notes needs the release notes text}"; shift 2 ;;
        --verify) VERIFY="${2:?--verify needs a version, e.g. --verify 1.5.0}"; shift 2 ;;
        *) echo "✗ Unknown argument: $1" >&2; exit 1 ;;
    esac
done

# Prints each required file that release $1 lacks (empty when complete).
# Fails if gh cannot read the release at all.
missing_assets() {
    local have f
    have=$(gh release view "$1" --json assets --jq '.assets[].name') || return 1
    for f in "${ASSETS[@]}"; do
        grep -qxF "$f" <<<"$have" || echo "$f"
    done
}

verify_release() {
    local missing
    if ! missing=$(missing_assets "$1" 2>/dev/null); then
        echo "✗ No GitHub release $1 (or gh could not read it)." >&2
        return 1
    fi
    if [[ -n "$missing" ]]; then
        echo "✗ Release $1 lacks: $(echo $missing)" >&2
        return 1
    fi
    echo "✓ Release $1 has ${ASSETS[*]}"
}

if ! gh auth status >/dev/null 2>&1; then
    echo "✗ gh is not authenticated — run: gh auth login" >&2
    exit 1
fi

if [[ -n "$VERIFY" ]]; then
    verify_release "$VERIFY"
    exit $?
fi

# --- Version from manifest.json (the single source of truth) ---
VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' manifest.json | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
if [[ -z "$VERSION" ]]; then
    echo "✗ Could not read version from manifest.json" >&2
    exit 1
fi
echo "→ Releasing version: $VERSION"

# --- Guards ---
# Static checks, including the versions.json entry: it must map this
# version to manifest.json's minAppVersion (stale copy-paste guard).
./scripts/check.sh

if [[ -n "$(git status --porcelain)" ]]; then
    echo "✗ Working tree is dirty — commit or stash first." >&2
    git status --short >&2
    exit 1
fi

RESUME=""
if git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null; then
    if [[ "$(git rev-list -n 1 "$VERSION")" != "$(git rev-parse HEAD)" ]]; then
        echo "✗ Tag $VERSION already exists on another commit. Bump the version in manifest.json first." >&2
        exit 1
    fi
    echo "→ Tag $VERSION already points at HEAD — resuming."
    RESUME=1
fi

# --- Push any unpushed commits, then tag + release ---
git push
[[ -n "$RESUME" ]] || git tag "$VERSION"
git push origin "$VERSION"
if gh release view "$VERSION" >/dev/null 2>&1; then
    echo "→ Release $VERSION already exists — checking its files."
else
    gh release create "$VERSION" "${ASSETS[@]}" --title "$VERSION" --notes "$NOTES"
fi

# --- Verify, re-uploading anything the create step dropped ---
MISSING=$(missing_assets "$VERSION")
if [[ -n "$MISSING" ]]; then
    echo "! Release $VERSION lacks: $(echo $MISSING) — uploading again." >&2
    # Word-splitting is intended: one file name per word, none has spaces.
    gh release upload "$VERSION" $MISSING --clobber
fi
verify_release "$VERSION"

echo "✓ Released $VERSION"
gh release view "$VERSION" --json tagName,url,assets \
    --jq '"  tag: \(.tagName)\n  url: \(.url)\n  assets: \([.assets[].name] | join(", "))"'
