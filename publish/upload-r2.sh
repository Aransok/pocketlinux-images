#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Uploads dist/ (tarballs, checksums, manifest.json) to Cloudflare R2 with rclone.
#
# Required environment:
#   R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
# Optional:
#   R2_BUCKET   bucket name (default pocketlinux-images)
#   DIST_DIR    directory to upload (default <repo>/dist)
#   DRY_RUN=1   show what would be copied, change nothing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
BUCKET="${R2_BUCKET:-pocketlinux-images}"

die() { echo "upload-r2: $*" >&2; exit 1; }

command -v rclone >/dev/null || die "rclone not found"
for v in R2_ACCOUNT_ID R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY; do
  [ -n "${!v:-}" ] || die "$v is not set"
done
[ -d "$DIST_DIR" ] || die "no such directory: $DIST_DIR"
[ -f "$DIST_DIR/manifest.json" ] || die "manifest.json missing, run manifest/make-manifest.py first"
compgen -G "$DIST_DIR/*.tar.xz" >/dev/null || die "no tarballs in $DIST_DIR"

# Remote "r2" is defined purely through environment variables, no config file.
export RCLONE_CONFIG_R2_TYPE=s3
export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
export RCLONE_CONFIG_R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export RCLONE_CONFIG_R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
export RCLONE_CONFIG_R2_ACL=private
export RCLONE_CONFIG_R2_NO_CHECK_BUCKET=true

extra=()
[ "${DRY_RUN:-0}" = "1" ] && extra+=(--dry-run)

# Versioned files never change, so existing ones are left alone.
echo "upload-r2: uploading tarballs and checksums to r2:$BUCKET"
rclone copy "$DIST_DIR" "r2:$BUCKET" \
  --include '*.tar.xz' --include '*.tar.xz.sha256' \
  --ignore-existing --transfers 2 --s3-upload-concurrency 4 \
  --s3-chunk-size 64M --progress "${extra[@]}"

# The manifest goes last so clients never see a manifest that points at a
# file that has not been uploaded yet. It must not be cached.
echo "upload-r2: uploading manifest.json"
rclone copyto "$DIST_DIR/manifest.json" "r2:$BUCKET/manifest.json" \
  --header-upload "Cache-Control: no-cache" \
  --header-upload "Content-Type: application/json" "${extra[@]}"

echo "upload-r2: done"
