#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Builds a Pocket Linux rootfs tarball from profiles/<profile>.yaml.
#
# usage: build/build-image.sh <profile>
#
# Environment:
#   IMAGE_VERSION   version string for the output name (default: git tag, else
#                   the profile version)
#   DIST_DIR        output directory (default: <repo>/dist)
#   SOURCE_DATE_EPOCH  timestamp clamp for reproducible output (default: last
#                   git commit time, else the current time)
#   PL_APT_CACHE    optional directory used to cache downloaded .deb files
#   PL_BUILDER      force "mmdebstrap" or "debootstrap" (default: auto)
#   PL_MIRROR       override the package mirror
#   PL_SKIP_QEMU_CHECK  skip the emulation sanity check (for dry runs)
#   PL_STRICT       set to 1 to make optional hooks fatal
#   XZ_OPT_LEVEL    xz level (default 9)
#
# Needs root for debootstrap, and for mmdebstrap when user namespaces are not
# available. When run as a normal user, mmdebstrap unshare mode is used.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"

die() { echo "build-image: $*" >&2; exit 1; }
log() { echo "build-image: $*" >&2; }

[ $# -eq 1 ] || die "usage: $0 <profile>   (see $ROOT/profiles)"
profile="$1"
profile_file="$ROOT/profiles/$profile.yaml"
[ -f "$profile_file" ] || die "no such profile: $profile_file"

command -v python3 >/dev/null || die "python3 is required to read profiles"
profile_vars="$(python3 -I "$ROOT/build/plprofile.py" "$profile_file" --shell)" || exit 1
eval "$profile_vars"
[ "$PL_NAME" = "$profile" ] || die "profile name '$PL_NAME' does not match file name '$profile'"

for h in $PL_HOOKS; do
  [ -f "$ROOT/hooks/$h.sh" ] || die "hook not found: hooks/$h.sh"
done

# Version
if [ -n "${IMAGE_VERSION:-}" ]; then
  PL_VERSION="$IMAGE_VERSION"
elif tag="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null)"; then
  PL_VERSION="${tag#v}"
else
  PL_VERSION="${PL_PROFILE_VERSION:-0.0.0}"
fi
[[ "$PL_VERSION" =~ ^[A-Za-z0-9._+~-]+$ ]] || die "bad version string: $PL_VERSION"

# Reproducible timestamps
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
  SOURCE_DATE_EPOCH="$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || date +%s)"
fi
export SOURCE_DATE_EPOCH

# Base distribution
case "$PL_BASE" in
  debian-trixie)
    suite=trixie
    mirror="${PL_MIRROR:-http://deb.debian.org/debian}"
    components="main"
    ;;
  ubuntu-noble)
    suite=noble
    mirror="${PL_MIRROR:-http://ports.ubuntu.com/ubuntu-ports}"
    components="main universe"
    ;;
  *) die "unsupported base: $PL_BASE" ;;
esac

# Choose builder
host_arch="$(uname -m)"
builder="${PL_BUILDER:-}"
if [ -z "$builder" ]; then
  if command -v mmdebstrap >/dev/null; then
    builder=mmdebstrap
  elif command -v debootstrap >/dev/null; then
    builder=debootstrap
  else
    die "neither mmdebstrap nor debootstrap found (apt install mmdebstrap)"
  fi
fi
command -v "$builder" >/dev/null || die "$builder not found"

if [ "$host_arch" != "aarch64" ] && [ "$host_arch" != "arm64" ] && [ -z "${PL_SKIP_QEMU_CHECK:-}" ]; then
  [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] || [ -x /usr/bin/qemu-aarch64-static ] \
    || die "host is $host_arch: install qemu-user-static and binfmt-support for arm64 emulation"
  log "host is $host_arch, building through qemu user emulation (slow)"
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/pl-build.XXXXXX")"
cleanup() {
  if [ -n "${proc_mounted:-}" ]; then umount "$work/rootfs/proc" 2>/dev/null || true; fi
  rm -rf "$work"
}
trap cleanup EXIT

# Stage hooks plus an env file that every hook sources.
stage="$work/stage/pl"
mkdir -p "$stage" "$DIST_DIR"
cp -a "$ROOT/hooks" "$stage/hooks"
cp -a "$ROOT/hooks/files" "$stage/files"
{
  printf 'export PL_NAME=%q\n' "$PL_NAME"
  printf 'export PL_DISPLAY_NAME=%q\n' "$PL_DISPLAY_NAME"
  printf 'export PL_VERSION=%q\n' "$PL_VERSION"
  printf 'export PL_BASE=%q\n' "$PL_BASE"
  printf 'export PL_ARCH=%q\n' "$PL_ARCH"
  printf 'export PL_DESKTOP=%q\n' "$PL_DESKTOP"
  printf 'export PL_STRICT=%q\n' "${PL_STRICT:-0}"
  printf 'export DEBIAN_FRONTEND=noninteractive\n'
} > "$stage/env"

# apt itself is not part of minbase on Ubuntu, so always include it.
include_csv="$(echo "apt $PL_PACKAGES" | tr " " "\n" | awk '!seen[$0]++' | paste -sd, -)"
tarball="$work/rootfs.tar"
log "profile=$PL_NAME base=$PL_BASE suite=$suite version=$PL_VERSION builder=$builder"

build_mmdebstrap() {
  local args=(--variant=minbase --architectures=arm64 "--components=$components"
    "--include=$include_csv" "--aptopt=Acquire::Languages \"none\"")
  if [ "$PL_RECOMMENDS" = "true" ]; then
    args+=("--aptopt=APT::Install-Recommends \"true\"")
  else
    args+=("--aptopt=APT::Install-Recommends \"false\"")
  fi
  if [ -n "${PL_APT_CACHE:-}" ]; then
    mkdir -p "$PL_APT_CACHE"
    # Special commands (sync-in, sync-out, copy-in) only work as a whole hook string,
    # never inside sh -c, so the mkdir gets its own hook.
    args+=("--setup-hook=mkdir -p \"\$1/var/cache/apt/archives\""
           "--setup-hook=sync-in \"$PL_APT_CACHE\" /var/cache/apt/archives"
           "--customize-hook=sync-out /var/cache/apt/archives \"$PL_APT_CACHE\"")
  fi
  args+=("--customize-hook=copy-in \"$stage\" /tmp")
  local h
  for h in $PL_HOOKS; do
    args+=("--customize-hook=chroot \"\$1\" bash /tmp/pl/hooks/$h.sh")
  done
  args+=("--customize-hook=chroot \"\$1\" rm -rf /tmp/pl")
  mmdebstrap "${args[@]}" "$suite" "$tarball" "$mirror"
}

build_debootstrap() {
  [ "$(id -u)" -eq 0 ] || die "debootstrap needs root"
  [ "$PL_RECOMMENDS" = "true" ] && log "note: debootstrap ignores install_recommends"
  local root="$work/rootfs" foreign=()
  mkdir -p "$root"
  if [ "$host_arch" != "aarch64" ] && [ "$host_arch" != "arm64" ]; then
    foreign=(--foreign)
  fi
  debootstrap --arch=arm64 --variant=minbase "--components=${components// /,}" \
    "--include=$include_csv" "${foreign[@]}" "$suite" "$root" "$mirror"
  if [ "${#foreign[@]}" -gt 0 ]; then
    local qemu
    qemu="$(command -v qemu-aarch64-static)" || die "qemu-aarch64-static not found"
    install -D -m 0755 "$qemu" "$root/usr/bin/qemu-aarch64-static"
    chroot "$root" /debootstrap/debootstrap --second-stage
  fi
  mount -t proc proc "$root/proc"
  proc_mounted=1
  cp -a "$stage" "$root/tmp/pl"
  local h
  for h in $PL_HOOKS; do
    chroot "$root" bash "/tmp/pl/hooks/$h.sh"
  done
  rm -rf "$root/tmp/pl" "$root/usr/bin/qemu-aarch64-static"
  umount "$root/proc"
  proc_mounted=""
  tar --numeric-owner --sort=name --mtime="@$SOURCE_DATE_EPOCH" \
    --format=posix --pax-option=delete=atime,delete=ctime \
    -C "$root" -cf "$tarball" .
}

case "$builder" in
  mmdebstrap) build_mmdebstrap ;;
  debootstrap) build_debootstrap ;;
  *) die "unknown builder: $builder" ;;
esac

# Report size of the unpacked tree (sum of regular file sizes in the tar).
unpacked_mb="$(tar -tvf "$tarball" | awk '{s+=$3} END {printf "%d", s/1048576}')"
log "unpacked size: ${unpacked_mb} MB"
if [ -n "$PL_MAX_MB" ] && [ "$unpacked_mb" -gt "$PL_MAX_MB" ]; then
  log "WARNING: unpacked size ${unpacked_mb} MB exceeds target ${PL_MAX_MB} MB"
fi

out_name="$PL_NAME-$PL_VERSION-arm64.tar.xz"
out="$DIST_DIR/$out_name"
log "compressing with xz -${XZ_OPT_LEVEL:-9} (multithreaded)"
xz -"${XZ_OPT_LEVEL:-9}" -T0 -c "$tarball" > "$out.part"
mv "$out.part" "$out"
(cd "$DIST_DIR" && sha256sum "$out_name" > "$out_name.sha256")
log "wrote $out ($(du -h "$out" | cut -f1))"
log "wrote $out.sha256"
