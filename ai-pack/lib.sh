# shellcheck shell=bash
# SPDX-License-Identifier: MIT
# Copyright (c) Pocket Linux contributors
#
# Shared helpers for the ai-pack install scripts. Source this file, do not run it.

# Where logs go. Override with PL_LOG_DIR.
PL_LOG_DIR="${PL_LOG_DIR:-$HOME/.pocketlinux/logs}"

# pl_init NAME: start logging to $PL_LOG_DIR/NAME.log (and to the terminal).
pl_init() {
  mkdir -p "$PL_LOG_DIR"
  PL_LOG_FILE="$PL_LOG_DIR/$1.log"
  exec > >(tee -a "$PL_LOG_FILE") 2>&1
  pl_log "log file: $PL_LOG_FILE"
}

pl_log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
pl_warn() { printf '[%s] WARNING: %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
pl_die() { printf '[%s] ERROR: %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }
pl_have() { command -v "$1" >/dev/null 2>&1; }

# pl_sudo CMD...: run as root, using sudo only when needed.
pl_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif pl_have sudo; then
    sudo "$@"
  else
    pl_die "need root or sudo to run: $*"
  fi
}

# pl_apt_install PKG...: install packages that are not present yet.
pl_apt_install() {
  local missing=() p
  for p in "$@"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  [ "${#missing[@]}" -eq 0 ] && return 0
  pl_log "apt: installing ${missing[*]}"
  pl_sudo apt-get update
  pl_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
}

# pl_path_line DIR: make sure DIR is on PATH now and in ~/.bashrc.
pl_path_line() {
  local dir="$1" line
  case ":$PATH:" in *":$dir:"*) ;; *) export PATH="$dir:$PATH" ;; esac
  line="export PATH=\"$dir:\$PATH\""
  touch "$HOME/.bashrc"
  grep -qxF "$line" "$HOME/.bashrc" || printf '%s\n' "$line" >> "$HOME/.bashrc"
}

# pl_node_major: print the major version of node, or 0 when missing.
pl_node_major() {
  if pl_have node; then node -p 'process.versions.node.split(".")[0]'; else echo 0; fi
}

# pl_ensure_node MIN: make sure node >= MIN and npm exist.
# Tries apt first, then the official arm64 tarball from nodejs.org.
pl_ensure_node() {
  local min="$1"
  if [ "$(pl_node_major)" -ge "$min" ] && pl_have npm; then
    return 0
  fi
  pl_apt_install nodejs npm || true
  if [ "$(pl_node_major)" -ge "$min" ] && pl_have npm; then
    return 0
  fi
  pl_log "node >= $min not available from apt, installing the official tarball"
  pl_apt_install curl ca-certificates xz-utils
  local arch tmp base file sum
  case "$(uname -m)" in
    aarch64|arm64) arch=arm64 ;;
    x86_64) arch=x64 ;;
    *) pl_die "unsupported architecture $(uname -m)" ;;
  esac
  tmp="$(mktemp -d)"
  base="https://nodejs.org/dist/latest-v22.x"
  curl -fsSL "$base/SHASUMS256.txt" -o "$tmp/SHASUMS256.txt"
  file="$(awk -v a="linux-$arch.tar.xz" '$2 ~ a"$" {print $2; exit}' "$tmp/SHASUMS256.txt")"
  [ -n "$file" ] || pl_die "no matching node tarball found"
  curl -fsSL "$base/$file" -o "$tmp/$file"
  sum="$(awk -v f="$file" '$2 == f {print $1}' "$tmp/SHASUMS256.txt")"
  echo "$sum  $tmp/$file" | sha256sum -c - >/dev/null || pl_die "node tarball checksum mismatch"
  pl_sudo tar -xJf "$tmp/$file" -C /usr/local --strip-components=1
  rm -rf "$tmp"
  hash -r
  [ "$(pl_node_major)" -ge "$min" ] || pl_die "node install failed"
}

# pl_npm_global PKG [extra npm args]: install a global npm package.
# Uses the system prefix when writable, otherwise ~/.local.
pl_npm_global() {
  local prefix
  prefix="$(npm config get prefix 2>/dev/null || echo /usr)"
  if [ ! -w "$prefix/lib" ] && [ "$(id -u)" -ne 0 ]; then
    export NPM_CONFIG_PREFIX="$HOME/.local"
    mkdir -p "$HOME/.local/bin"
    pl_path_line "$HOME/.local/bin"
    pl_log "npm prefix is not writable, using $NPM_CONFIG_PREFIX"
  fi
  npm install -g "$@"
}
