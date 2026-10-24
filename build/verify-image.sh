#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Cheap sanity checks on a built tarball (no root needed, no unpacking).
# usage: build/verify-image.sh dist/<name>-<version>-arm64.tar.xz [max_unpacked_mb]
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: $0 <tarball> [max_unpacked_mb]" >&2; exit 2; }
tarball="$1"
max_mb="${2:-}"
sum_file="$tarball.sha256"

if [ -f "$sum_file" ]; then
  (cd "$(dirname "$tarball")" && sha256sum -c "$(basename "$sum_file")")
fi

listing="$(mktemp)"
names="$(mktemp)"
trap 'rm -f "$listing" "$names"' EXIT
tar -tvJf "$tarball" > "$listing"
# Last field only (symlink targets are handled by the " -> " check below). A separate file
# avoids grep -q closing a pipe early, which trips pipefail with exit 141.
awk '{print $NF}' "$listing" > "$names"

fail=0
for path in etc/pocketlinux/release usr/local/bin/start-desktop usr/local/bin/pl-doctor \
            etc/sudoers.d/90-pocketlinux bin/bash; do
  if ! grep -Eq "^(\./)?${path}$" "$names" && ! grep -Eq " (\./)?${path} -> " "$listing"; then
    # usrmerge images list bin as a symlink to usr/bin
    if [ "$path" = "bin/bash" ] && grep -Eq ' (\./)?usr/bin/bash$' "$listing"; then
      continue
    fi
    echo "MISSING: $path" >&2
    echo "  nearby entries:" >&2
    grep -E "$(dirname "$path")" "$listing" | sed -n 1,5p | sed 's/^/    /' >&2 || true
    fail=1
  fi
done

unpacked_mb="$(awk '{s+=$3} END {printf "%d", s/1048576}' "$listing")"
echo "unpacked: ${unpacked_mb} MB"
if [ -n "$max_mb" ] && [ "$unpacked_mb" -gt "$max_mb" ]; then
  echo "TOO BIG: ${unpacked_mb} MB > ${max_mb} MB" >&2
  fail=1
fi
[ "$fail" -eq 0 ] && echo "verify ok: $tarball"
exit "$fail"
