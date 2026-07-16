#!/usr/bin/env bash
#
# release.sh — cut an Obsidian community-theme release.
#
# The Obsidian directory does NOT read the repo directly — it reads GitHub
# Releases, and requires a release whose tag EXACTLY equals the version in
# manifest.json (no "v" prefix). This script reads that version, sanity-
# checks the repo, then tags + pushes + creates the release with theme.css,
# manifest.json and versions.json attached.
#
# Usage:
#   ./release.sh                 # release the version in manifest.json
#   ./release.sh --notes "..."   # with custom release notes
#
# Requires: git, gh (authenticated: gh auth status).

set -euo pipefail
cd "$(dirname "$0")"

NOTES="Theme update. Install/update via Settings → Appearance → Themes → Manage → \"Claude Code Orange\"."
if [[ "${1:-}" == "--notes" && -n "${2:-}" ]]; then
    NOTES="$2"
fi

# --- Version from manifest.json (the single source of truth) ---
VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' manifest.json | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
if [[ -z "$VERSION" ]]; then
    echo "✗ Could not read version from manifest.json" >&2
    exit 1
fi
echo "→ Releasing version: $VERSION"

# versions.json maps each release to its minAppVersion for the community
# browser — it must have an entry for the released version, and that entry
# must agree with manifest.json's minAppVersion (stale copy-paste guard).
MINAPP=$(grep -o '"minAppVersion"[[:space:]]*:[[:space:]]*"[^"]*"' manifest.json | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
if ! grep -q "\"${VERSION//./\\.}\"[[:space:]]*:[[:space:]]*\"${MINAPP//./\\.}\"" versions.json; then
    echo "✗ versions.json needs the entry \"$VERSION\": \"$MINAPP\" (matching manifest.json's minAppVersion)." >&2
    exit 1
fi

# --- Guards ---
if [[ -n "$(git status --porcelain)" ]]; then
    echo "✗ Working tree is dirty — commit or stash first." >&2
    git status --short >&2
    exit 1
fi

if git rev-parse "$VERSION" >/dev/null 2>&1; then
    echo "✗ Tag $VERSION already exists. Bump the version in manifest.json first." >&2
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "✗ gh is not authenticated — run: gh auth login" >&2
    exit 1
fi

# --- Push any unpushed commits, then tag + release ---
git push
git tag "$VERSION"
git push origin "$VERSION"
gh release create "$VERSION" theme.css manifest.json versions.json --title "$VERSION" --notes "$NOTES"

echo "✓ Released $VERSION"
gh release view "$VERSION" --json tagName,url,assets \
    --jq '"  tag: \(.tagName)\n  url: \(.url)\n  assets: \([.assets[].name] | join(", "))"'
