#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Attaches dist/ tarballs to a GitHub Release as a mirror of the R2 downloads.
#
# usage: publish/github-release.sh <tag> [owner/repo]
# Needs the gh CLI, logged in (gh auth login) or GH_TOKEN set.
# Creates the release when it does not exist yet; existing assets are replaced.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"

die() { echo "github-release: $*" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: $0 <tag> [owner/repo]"
tag="$1"
repo_args=()
[ $# -ge 2 ] && repo_args=(--repo "$2")

command -v gh >/dev/null || die "gh not found"
compgen -G "$DIST_DIR/*.tar.xz" >/dev/null || die "no tarballs in $DIST_DIR"

assets=("$DIST_DIR"/*.tar.xz "$DIST_DIR"/*.sha256)
[ -f "$DIST_DIR/manifest.json" ] && assets+=("$DIST_DIR/manifest.json")

if ! gh release view "$tag" "${repo_args[@]}" >/dev/null 2>&1; then
  echo "github-release: creating release $tag"
  gh release create "$tag" "${repo_args[@]}" --title "$tag" --generate-notes
fi
echo "github-release: uploading ${#assets[@]} assets to $tag"
gh release upload "$tag" "${assets[@]}" "${repo_args[@]}" --clobber
echo "github-release: done"
